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

using namespace llvm;

#define DEBUG_TYPE "allocatedescriptors"

namespace {

class AllocateDescriptorsPass : public ModulePass {
public:
  static char ID;
  AllocateDescriptorsPass() : ModulePass(ID) {}
  bool runOnModule(Module &M) override;
};
} // namespace

char AllocateDescriptorsPass::ID = 0;
static RegisterPass<AllocateDescriptorsPass> X("AllocateDescriptorsPass",
                                               "Allocate resource descriptors");

namespace clspv {
ModulePass *createAllocateDescriptorsPass() {
  return new AllocateDescriptorsPass();
}
} // namespace clspv

bool AllocateDescriptorsPass::runOnModule(Module &M) { return false; }
