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
#include "llvm/ADT/SmallVector.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
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

bool DirectResourceAccessPass::runOnModule(Module &M) {
  bool Changed = false;

  return Changed;
}
