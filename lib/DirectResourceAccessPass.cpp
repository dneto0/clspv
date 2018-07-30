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

  auto functions = LevelOrderedFunctions(M);

  return Changed;
}

UniqueVector<Function *>
DirectResourceAccessPass::LevelOrderedFunctions(Module &M) {
  // Use a breadth-first search.
  const uint32_t kMaxDepth = UINT32_MAX;
  // Map a function to its depth.  This will be updated as we traverse
  // the call graph.
  DenseMap<Function*, uint32_t> depth;

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
      depth[&F] = 1;
    }
  }
  for (Function &F : M) {
    if (F.isDeclaration()) {
      continue;
    }
    if (F.getCallingConv() == CallingConv::SPIR_FUNC) {
      functions.insert(&F);
      // The depth will be updated later if the function is reachable.
      depth[&F] = kMaxDepth;
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
    int i =0;
    for (Function *fn : result) {
      outs() << "DRA:  [" << i << "] " << fn->getName() << "\n";
      i++;
    }
  }
  return result;
}
} // namespace
