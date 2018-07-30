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

#include <climits>
#include <vector>

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/UniqueVector.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"

#include "clspv/Option.h"
#include "clspv/Passes.h"

#include "ArgKind.h"

using namespace llvm;

#define DEBUG_TYPE "directresourceaccess"

namespace {

cl::opt<bool> ShowDRA("show-dra", cl::init(false), cl::Hidden,
                      cl::desc("Show direct resource access details"));

using SamplerMapType = llvm::ArrayRef<std::pair<unsigned, std::string>>;

class DirectResourceAccessPass final : public ModulePass {
public:
  static char ID;
  DirectResourceAccessPass() : ModulePass(ID) {}
  bool runOnModule(Module &M) override;

private:
  // Return the functions reachable from entry point functions, in level-ized
  // order.  The level of a function F is the length of the longest path in the
  // call graph from an entry point to F.  OpenCL C does not permit recursion
  // or function or pointers, so this is always well defined.  The ordering
  // should be reproducible from one run to the next.
  UniqueVector<Function *> LevelOrderedFunctions(Module &);

  // For each kernel argument that will map to a resource variable (descriptor),
  // try to rewrite the uses of the argument as a direct access of the resource.
  // We can only do this if all the callees of the function use the same
  // resource access value for that argument.  Returns true if the module
  // changed.
  bool RewriteResourceAccesses(Function *fn);
  // Rewrite uses of this resrouce-based arg if all the callers pass in the
  // same resource access.  Returns true if the module changed.
  bool RewriteAccessesForArg(Function *F, int arg_index, Argument &arg);
};
} // namespace

char DirectResourceAccessPass::ID = 0;
static RegisterPass<DirectResourceAccessPass> X("DirectResourceAccessPass",
                                                "Direct resource access");

namespace clspv {
ModulePass *createDirectResourceAccessPass() {
  return new DirectResourceAccessPass();
}
} // namespace clspv

namespace {
bool DirectResourceAccessPass::runOnModule(Module &M) {
  bool Changed = false;

  auto ordered_functions = LevelOrderedFunctions(M);
  for (auto *fn : ordered_functions) {
    Changed |= RewriteResourceAccesses(fn);
  }

  return Changed;
}

UniqueVector<Function *>
DirectResourceAccessPass::LevelOrderedFunctions(Module &M) {
  // Use a breadth-first search.
  const uint32_t kMaxDepth = UINT32_MAX;

  // Make an ordered list of all functions having bodies, with kernel entry
  // point listed first.
  UniqueVector<Function *> functions;
  SmallVector<Function *, 10> entry_points;
  for (Function &F : M) {
    if (F.isDeclaration()) {
      continue;
    }
    if (F.getCallingConv() == CallingConv::SPIR_KERNEL) {
      functions.insert(&F);
      entry_points.push_back(&F);
    }
  }
  for (Function &F : M) {
    if (F.isDeclaration()) {
      continue;
    }
    if (F.getCallingConv() == CallingConv::SPIR_FUNC) {
      functions.insert(&F);
    }
  }

  // Map each function to the functions it calls.
  std::map<Function *, SmallVector<Function *, 3>> calls_functions;
  for (Function *callee : functions) {
    for (auto &use : callee->uses()) {
      if (auto *call = dyn_cast<CallInst>(use.getUser())) {
        Function *caller = call->getParent()->getParent();
        calls_functions[caller].push_back(callee);
      }
    }
  }
  // Sort the callees in module-order.  This helps us produce a deterministic
  // result.
  for (auto &pair : calls_functions) {
    auto &callees = pair.second;
    std::sort(callees.begin(), callees.end(),
              [&functions](Function *lhs, Function *rhs) {
                return functions.idFor(lhs) < functions.idFor(rhs);
              });
  }

  UniqueVector<Function *> result;
  SmallVector<Function *, 10> work_list(entry_points.begin(),
                                        entry_points.end());
  // Use a read cursor to scan from left to right.
  for (size_t r = 0; r < work_list.size(); r++) {
    Function *fn = work_list[r];
    // Even though recursion is not allowed, be defensive here and guard
    // against an infinite loop in case the user gave us a bad program.
    if (result.idFor(fn) == 0) {
      result.insert(fn);
      auto &callees = calls_functions[fn];
      work_list.insert(work_list.end(), callees.begin(), callees.end());
    }
  }
  if (ShowDRA) {
    outs() << "DRA: Ordered functions:\n";
    int i = 0;
    for (Function *fn : result) {
      outs() << "DRA:  [" << i << "] " << fn->getName() << "\n";
      i++;
    }
  }
  return result;
}

bool DirectResourceAccessPass::RewriteResourceAccesses(Function *fn) {
  bool Changed = false;
  int arg_index = 0;
  for (Argument &arg : fn->args()) {
    switch (clspv::GetArgKindForType(arg.getType())) {
    case clspv::ArgKind::Buffer:
    case clspv::ArgKind::ReadOnlyImage:
    case clspv::ArgKind::WriteOnlyImage:
    case clspv::ArgKind::Sampler:
      Changed |= RewriteAccessesForArg(fn, arg_index, arg);
      break;
    }
    arg_index++;
  }
  return Changed;
}

bool DirectResourceAccessPass::RewriteAccessesForArg(Function *fn,
                                                     int arg_index,
                                                     Argument &arg) {
  bool Changed = false;

  // We can convert a parameter to a direct resource access if it is
  // either a direct call to a clspv.resource.var.* or if it a GEP of
  // such a thing (where the GEP can only have zero indices).
  struct ParamInfo {
    // The resource-access builtin function.  (@clspv.resource.var.*)
    Function *var_fn;
    // The descriptor set.
    uint32_t set;
    // The binding.
    uint32_t binding;
    // If the parameter is a GEP, then this is the number of zero-indices
    // the GEP used.
    unsigned num_gep_zeroes;
  };
  // The common valid parameter info across all the callers seen soo far.

  bool seen_one = false;
  ParamInfo common;
  // Tries to merge the given parameter info into |common|.  If it is the first
  // time we've tried, then save it.  Returns true if there is no conflict.
  auto merge_param_info = [&seen_one, &common](const ParamInfo &pi) {
    if (!seen_one) {
      common = pi;
      seen_one = true;
      return true;
    }
    return pi.var_fn == common.var_fn && pi.set == common.set &&
           pi.binding == common.binding &&
           pi.num_gep_zeroes == common.num_gep_zeroes;
  };

  for (auto &use : fn->uses()) {
    if (auto *caller = dyn_cast<CallInst>(use.getUser())) {
      Value *value = caller->getArgOperand(arg_index);
      // We care about two cases:
      //     - a direct call to clspv.resource.var.*
      //     - a GEP with only zero indices, where the base pointer is

      // Unpack GEPs with zeros, if we can.  Rewrite |value| as we go along.
      unsigned num_gep_zeroes = 0;
      for (auto *gep = dyn_cast<GetElementPtrInst>(value); gep;
           gep = dyn_cast<GetElementPtrInst>(value)) {
        if (!gep->hasAllZeroIndices()) {
          return false;
        }
        num_gep_zeroes += gep->getNumIndices();
        value = gep->getPointerOperand();
      }
      if (auto *call = dyn_cast<CallInst>(value)) {
        // If the call is a call to a @clspv.resource.var.* function, then try
        // to merge it, assuming the given number of GEP zero-indices so far.
        if (call->getCalledFunction()->getName().startswith(
                "clspv.resource.var.")) {
          const auto set = uint32_t(
              dyn_cast<ConstantInt>(call->getOperand(0))->getZExtValue());
          const auto binding = uint32_t(
              dyn_cast<ConstantInt>(call->getOperand(1))->getZExtValue());
          if (!merge_param_info(
                  {call->getCalledFunction(), set, binding, num_gep_zeroes})) {
            return false;
          }
        } else {
          // A call but not to a resource access builtin function.
          return false;
        }
      } else {
        // Not a call.
        return false;
      }
    } else {
      // There isn't enough commonality.  Bail out without changing anything.
      return false;
    }
  }
  if (ShowDRA) {
    if (seen_one) {
      outs() << "DRA:  Rewrite " << fn->getName() << " arg " << arg_index << " "
             << arg.getName() << ": " << common.var_fn->getName() << " ("
             << common.set << "," << common.binding
             << ") zeroes: " << common.num_gep_zeroes << "\n";
    }
  }
  // TODO(dneto): Now rewrite the argument.

  return Changed;
}

} // namespace
