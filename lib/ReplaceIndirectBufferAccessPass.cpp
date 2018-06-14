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

#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"

#include "clspv/Option.h"

using namespace llvm;

#define DEBUG_TYPE "replaceindirectbufferaccess"

namespace {
class ReplaceIndirectBufferAccessPass : public ModulePass {
public:
  static char ID;
  ReplaceIndirectBufferAccessPass() : ModulePass(ID) {}
  bool runOnModule(Module &M) override;

private:
  // What makes a kernel argument require a new descriptor?
  struct KernelArgDiscriminant {
    // Different argument type requires different descriptor since logical
    // addressing requires strongly typed storage buffer variables.
    Type *type;
    // If we have multiple arguments of the same type to the same kernel,
    // then we have to use distinct descriptors because the user could
    // bind different storage buffers for them.  Use argument index
    // as a proxy for distinctness.  This might overcount, but we
    // don't worry about yet.
    unsigned arg_index;
  };

  using KernelArgDiscriminantMap = UniqueVector<KernelArgDiscriminant>;

  // Scans all kernel arguments, mapping pointer-to-global arguments to
  // unique discriminators.  Uses and populates |discrminant_map_|.
  void LoadDiscriminantMap();

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

  if (clspv::Option::DirectBufferAccess()) {
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
  }
}
