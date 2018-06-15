// Copyright 2018 The Clspv Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "llvm/ADT/DenseMap.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/CommandLine.h"

#include "clspv/Option.h"

#include "ArgKind.h"

using namespace llvm;

#define DEBUG_TYPE "replaceindirectbufferaccess"

namespace {

cl::opt<bool>
    ShowDiscriminants("dba-show-disc", cl::init(true), cl::Hidden,
                      cl::desc("Direct Buffer Access: Show discriminant map"));

class ReplaceIndirectBufferAccessPass : public ModulePass {
public:
  static char ID;
  ReplaceIndirectBufferAccessPass() : ModulePass(ID) {}
  bool runOnModule(Module &M) override;

private:
  // What makes a kernel argument require a new descriptor?
  struct KernelArgDiscriminant {
    KernelArgDiscriminant() : type(nullptr), arg_index(0) {}
    KernelArgDiscriminant(Type *the_type, int the_arg_index)
        : type(the_type), arg_index(the_arg_index) {}
    // Different argument type requires different descriptor since logical
    // addressing requires strongly typed storage buffer variables.
    Type *type;
    // If we have multiple arguments of the same type to the same kernel,
    // then we have to use distinct descriptors because the user could
    // bind different storage buffers for them.  Use argument index
    // as a proxy for distinctness.  This might overcount, but we
    // don't worry about yet.
    int arg_index;
  };
  struct KADDenseMapInfo {
    static KernelArgDiscriminant getEmptyKey() {
      return KernelArgDiscriminant(nullptr, 0);
    }
    static KernelArgDiscriminant getTombstoneKey() {
      return KernelArgDiscriminant(nullptr, -1);
    }
    static unsigned getHashValue(const KernelArgDiscriminant &key) {
      return unsigned(uintptr_t(key.type)) ^ key.arg_index;
    }
    static bool isEqual(const KernelArgDiscriminant &lhs,
                   const KernelArgDiscriminant &rhs) {
      return lhs.type == rhs.type && lhs.arg_index == rhs.arg_index;
    }
  };

  // Map a descriminant to a unique index.  We don't use a UniqueVector
  // because that requires operator< that I don't want to define on
  // llvm::Type*
  using KernelArgDiscriminantMap = DenseMap<KernelArgDiscriminant, int, KADDenseMapInfo>;

  // Scans all kernel arguments, mapping pointer-to-global arguments to
  // unique discriminators.  Uses and populates |discrminant_map_|.
  void LoadDiscriminantMap(Module &);

  KernelArgDiscriminantMap discriminant_map_;
};
} // namespace

char ReplaceIndirectBufferAccessPass::ID = 0;
static RegisterPass<ReplaceIndirectBufferAccessPass>
    X("ReplaceIndirectBufferAccessPass",
      "Repace indirect buffer accesses if requested");

namespace clspv {
ModulePass *createReplaceIndirectBufferAccessPass() {
  return new ReplaceIndirectBufferAccessPass();
}
} // namespace clspv

bool ReplaceIndirectBufferAccessPass::runOnModule(Module &M) {
  bool Changed = false;

  const bool do_it = clspv::Option::DirectBufferAccess() || ShowDiscriminants;

  if (do_it) {
    LoadDiscriminantMap(M);
  }

  return Changed;
}

void ReplaceIndirectBufferAccessPass::LoadDiscriminantMap(Module &M) {
  discriminant_map_.clear();
  for (Function &F : M) {
    // Only scan arguments of kernel functions that have bodies.
    if (F.isDeclaration() || F.getCallingConv() != CallingConv::SPIR_KERNEL) {
      continue;
    }
    int arg_index = 0;
    for (Argument &Arg : F.args()) {
      Type *argTy = Arg.getType();
      if (clspv::ArgKind::Buffer == clspv::GetArgKindForType(argTy)) {
        // Put it in if it isn't there.
        KernelArgDiscriminant key{argTy, arg_index};
        auto where = discriminant_map_.find(key);
        if (where == discriminant_map_.end()) {
          int index = int(discriminant_map_.size());
          discriminant_map_[key] = index;
          if (ShowDiscriminants) {
            outs() << "DBA: Map " << *argTy << " " << arg_index << " -> "
                   << index << "\n";
          }
        }
      }
      arg_index++;
    }
  }
}
