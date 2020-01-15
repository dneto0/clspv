
; RUN: clspv-opt -ReplaceOpenCLBuiltin %s -o %t.ll
; RUN: FileCheck %s < %t.ll

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spir-unknown-unknown"

; CHECK: [[conv:%[a-zA-Z0-9_.]+]] = uitofp i16 %x to half
; CHECK: ret half [[conv]]

define half@foo(i16 %x) {
entry:
  %call = call half @_Z12convert_halft(i16 %x)
  ret half %call
}

declare half @_Z12convert_halft(i16)
