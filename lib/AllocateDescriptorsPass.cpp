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

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"

#include "clspv/AddressSpace.h"
#include "clspv/Passes.h"

#include "DescriptorCounter.h"

using namespace llvm;

#define DEBUG_TYPE "allocatedescriptors"

namespace {

cl::opt<bool> ShowDescriptors("show-desc", cl::init(true), cl::Hidden,
                              cl::desc("Show descriptors"));

using SamplerMapType = llvm::ArrayRef<std::pair<unsigned, std::string>>;

class AllocateDescriptorsPass final : public ModulePass {
public:
  static char ID;
  AllocateDescriptorsPass()
      : ModulePass(ID), sampler_map_(), descriptor_set_(0), binding_(0) {}
  bool runOnModule(Module &M) override;

  SamplerMapType &sampler_map() { return sampler_map_; }

private:
  // Allocates descriptors for all samplers and kernel arguments that have uses.
  // Replace their uses with calls to a special compiler builtin.  Returns true
  // if we changed the module.
  bool AllocateDescriptors(Module &M);

  // Allocate descriptor for literal samplers.  Returns true if we changed the
  // module.
  bool AllocateLiteralSamplerDescriptors(Module &M);

  // Allocate descriptor for kernel arguments with uses.  Returns true if we
  // changed the module.
  bool AllocateKernelArgDescriptors(Module &M);

  // The sampler map, which is an array ref of pairs, each of which is the
  // sampler constant as an integer, followed by the string expression for
  // the sampler.
  SamplerMapType sampler_map_;

  // Which descriptor set are we using?  If none yet, then this is -1.
  int descriptor_set_;
  // The next binding number to use.
  int binding_;
};
} // namespace

char AllocateDescriptorsPass::ID = 0;
static RegisterPass<AllocateDescriptorsPass> X("AllocateDescriptorsPass",
                                               "Allocate resource descriptors");

namespace clspv {
ModulePass *createAllocateDescriptorsPass(SamplerMapType sampler_map) {
  auto *result = new AllocateDescriptorsPass();
  result->sampler_map() = sampler_map;
  return result;
}
} // namespace clspv

bool AllocateDescriptorsPass::runOnModule(Module &M) {
  bool Changed = false;

  // Samplers from the sampler map always grab descriptor set 0.
  Changed |= AllocateLiteralSamplerDescriptors(M);
  Changed |= AllocateKernelArgDescriptors(M);

  return Changed;
}

bool AllocateDescriptorsPass::AllocateLiteralSamplerDescriptors(Module &M) {
  if (ShowDescriptors) {
    outs() << "Allocate literal sampler descriptors\n";
  }
  bool Changed = false;
  auto init_fn = M.getFunction("__translate_sampler_initializer");
  if (init_fn && sampler_map_.size() == 0) {
    errs() << "error: kernel uses a literal sampler but option -samplermap "
              "has not been specified\n";
    llvm_unreachable("Sampler literal in source without sampler map!");
  }
  if (sampler_map_.size()) {
    Changed = true;
    if (ShowDescriptors) {
      outs() << "  Found " << sampler_map_.size()
             << " samplers in the sampler map\n";
    }
    // Replace all things that look like
    //  call %opencl.sampler_t addrspace(2)*
    //     @__translate_sampler_initializer(i32 sampler-literal-constant-value)
    //     #2
    //
    // with:
    //
    //   call %opencl.sampler_t addrspace(2)*
    //       @clspv.sampler.var.literal(i32 descriptor, i32 binding, i32
    //       index-into-sampler-map)
    //
    // We need to preserve the index into the sampler map so that later we can
    // generate the sampler lines in the descriptor map. That needs both the
    // literal value and the string expression for the literal.

    // Generate the function type for %clspv.sampler.var.literal
    IRBuilder<> Builder(M.getContext());
    auto *sampler_struct_ty = M.getTypeByName("opencl.sampler_t");
    if (!sampler_struct_ty) {
      sampler_struct_ty =
          StructType::create(M.getContext(), "opencl.sampler_t");
    }
    auto *sampler_ty =
        sampler_struct_ty->getPointerTo(clspv::AddressSpace::Constant);
    Type *i32 = Builder.getInt32Ty();
    FunctionType *fn_ty = FunctionType::get(sampler_ty, {i32, i32, i32}, false);

    auto *var_fn = M.getOrInsertFunction("clspv.sampler.var.literal", fn_ty);

    // Map sampler literal to binding number.
    DenseMap<unsigned, unsigned> binding_for_value;
    DenseMap<unsigned, unsigned> index_for_value;
    unsigned index = 0;
    for (auto sampler_info : sampler_map_) {
      const unsigned value = sampler_info.first;
      const std::string &expr = sampler_info.second;
      if (0 == binding_for_value.count(value)) {
        // Make a new entry.
        binding_for_value[value] = binding_++;
        index_for_value[value] = index;
        if (ShowDescriptors) {
          outs() << "  Map " << value << " to (" << descriptor_set_ << ","
                 << binding_for_value[value] << ") << " << expr << "\n";
        }
      }
      index++;
    }

    // Now replace calls to __translate_sampler_initializer
    if (init_fn) {
      for (auto user : init_fn->users()) {
        if (auto* call = dyn_cast<CallInst>(user)) {
          auto const_val = dyn_cast<ConstantInt>(call->getArgOperand(0));

          if (!const_val) {
            call->getArgOperand(0)->print(errs());
            llvm_unreachable(
                "Argument of sampler initializer was non-constant!");
          }

          const auto value = static_cast<unsigned>(const_val->getZExtValue());

          auto where = binding_for_value.find(value);
          if (where == binding_for_value.end()) {
            errs() << "Sampler literal " << value
                   << " was not in the sampler map\n";
            llvm_unreachable("Sampler literal was not found in sampler map!");
          }
          const unsigned binding = binding_for_value[value];
          const unsigned index = index_for_value[value];

          SmallVector<Value *, 3> args = {Builder.getInt32(descriptor_set_),
                                          Builder.getInt32(binding),
                                          Builder.getInt32(index)};
          if (ShowDescriptors) {
            outs() << "  translate literal sampler " << *const_val << " to ("
                   << descriptor_set_ << "," << binding << ")\n";
          }
          auto *new_call =
              CallInst::Create(var_fn, args, "", dyn_cast<Instruction>(call));
          call->replaceAllUsesWith(new_call);
          call->eraseFromParent();
        }
      }
      init_fn->eraseFromParent();
    }

    // Allocate the descriptor set we used.
    ++descriptor_set_;
    binding_ = 0;
    const auto set = clspv::TakeDescriptorIndex(&M);
    assert(set == descriptor_set_);
  } else {
    if (ShowDescriptors) {
      outs() << "  No sampler\n";
    }
  }
  return Changed;
}

bool AllocateDescriptorsPass::AllocateKernelArgDescriptors(Module &M) {
  bool Changed = false;
  outs() << "Allocate kernel arg descriptors\n";
#if 0
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
#endif
  return Changed;
}
