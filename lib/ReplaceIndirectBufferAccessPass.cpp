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

#include <string>

#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/CommandLine.h"

#include "clspv/AddressSpace.h"
#include "clspv/Option.h"

#include "ArgKind.h"
#include "DescriptorCounter.h"

using namespace llvm;

#define DEBUG_TYPE "replaceindirectbufferaccess"

namespace {

cl::opt<bool>
    ShowDiscriminants("dba-show-disc", cl::init(true), cl::Hidden,
                      cl::desc("Direct Buffer Access: Show discriminant map"));

class ReplaceIndirectBufferAccessPass : public ModulePass {
public:
  static char ID;
  ReplaceIndirectBufferAccessPass()
      : ModulePass(ID), descriptor_set_(-1), binding_(0) {}
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

  // LLVM objects we create for each descriptor.
  struct DescriptorInfo {
    DescriptorInfo() : resource_type(nullptr), var_fn(nullptr) {}
    DescriptorInfo(StructType *sty, Function *fn)
        : resource_type(sty), var_fn(fn) {}
    // The struct @clspv.resource.type.N = type { [0 x elemty] }
    llvm::StructType* resource_type;
    // The function that gives us the base pointer to the OpVariable.
    llvm::Function* var_fn;
  };

  // Map a descriminant to a unique index.  We don't use a UniqueVector
  // because that requires operator< that I don't want to define on
  // llvm::Type*
  using KernelArgDiscriminantMap = DenseMap<KernelArgDiscriminant, int, KADDenseMapInfo>;

  // Scans all kernel arguments, mapping pointer-to-global arguments to
  // unique discriminators.  Uses and populates |discrminant_map_|.
  void LoadDiscriminantMap(Module &);

  // Maps a discriminant to its unique index, starting at 0.
  KernelArgDiscriminantMap discriminant_map_;

  // Indexed by discriminant index.
  SmallVector<DescriptorInfo, 10> descriptor_info_;

  // Which descriptor set are we using?  If none yet, then this is -1.
  int descriptor_set_;
  // The next binding number to use.
  int binding_;
};
} // namespace

char ReplaceIndirectBufferAccessPass::ID = 0;
static RegisterPass<ReplaceIndirectBufferAccessPass>
    X("ReplaceIndirectBufferAccessPass",
      "Replace indirect buffer accesses if requested");

namespace clspv {
ModulePass *createReplaceIndirectBufferAccessPass() {
  return new ReplaceIndirectBufferAccessPass();
}
} // namespace clspv

bool ReplaceIndirectBufferAccessPass::runOnModule(Module &M) {
  bool Changed = false;
  return false;

  const bool do_it = clspv::Option::DirectBufferAccess() || ShowDiscriminants;

  if (do_it) {
    LoadDiscriminantMap(M);
  }

  return Changed;
}

void ReplaceIndirectBufferAccessPass::LoadDiscriminantMap(Module &M) {
  discriminant_map_.clear();
  IRBuilder<> Builder(M.getContext());
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

          // Save the new unique index for this discriminant.
          discriminant_map_[key] = index;

          // Now make a DescriptorInfo entry.

          // Allocate a descriptor set index if we haven't already gotten one.
          if (descriptor_set_ < 0) {
            descriptor_set_ = clspv::TakeDescriptorIndex(&M);
          }

          // If original argument is:
          //   Elem addrspace(1)*
          // Then make type:
          //   %clspv.resource.type.N = type { [0 x Elem] }
          auto *arr_type = ArrayType::get(argTy->getPointerElementType(), 0);
          auto *resource_type = StructType::create(
              {arr_type},
              std::string("clspv.resource.type.") + std::to_string(index));

          auto fn_name =
              std::string("clspv.resource.var.") + std::to_string(index);
          Function* var_fn = M.getFunction(fn_name);
          if (!var_fn) {
            // Make the function
            PointerType *ptrTy =
                PointerType::get(resource_type, clspv::AddressSpace::Global);
            // The paramters are:
            //  arg index
            //  descriptor set
            //  binding
            Type *i32 = Builder.getInt32Ty();
            FunctionType *fnTy =
                FunctionType::get(ptrTy, {i32, i32, i32}, false);
#if 0
                FunctionType::get(ptrTy, {Builder.getInt32(arg_index),
                                          Builder.getInt32(descriptor_set_),
                                          Builder.getInt32(binding_++)});
#endif
            var_fn = cast<Function>(M.getOrInsertFunction(fn_name, fnTy));
          }
          descriptor_info_.push_back(DescriptorInfo(resource_type, var_fn));

          if (ShowDiscriminants) {
            outs() << "DBA: Map " << *argTy << " " << arg_index << " -> "
                   << index << "\n";
            outs() << "DBA:   resource type  " << *resource_type << "\n";
            outs() << "DBA:   var fn         " << *var_fn << "\n";
          }
        }
      }
      arg_index++;
    }
  }
}
