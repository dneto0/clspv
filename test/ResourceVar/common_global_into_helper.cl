// RUN: clspv %s -o %t.spv -cluster-pod-kernel-args -descriptormap=%t.map -direct-resource-access
// RUN: FileCheck -check-prefix=MAP %s < %t.map
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: spirv-val --target-env vulkan1.0 %t.spv

// TODO(dneto): SPIR-V result is expected to change.  We should commonize
// resource access.



//      MAP: kernel,foo,arg,A,argOrdinal,0,descriptorSet,0,binding,0,offset,0,argKind,buffer
// MAP-NEXT: kernel,foo,arg,n,argOrdinal,1,descriptorSet,0,binding,1,offset,0,argKind,pod
// MAP-NEXT: kernel,bar,arg,B,argOrdinal,0,descriptorSet,0,binding,0,offset,0,argKind,buffer
// MAP-NEXT: kernel,bar,arg,m,argOrdinal,1,descriptorSet,0,binding,1,offset,0,argKind,pod
// MAP-NONE: kernel



float core(global float *arr, int n) {
  return arr[n];
}

float apple(global float *arr, int n) {
  return core(arr, n) + core(arr, n+1);
}

void kernel __attribute__((reqd_work_group_size(1, 1, 1))) foo(global float* A, int n)
{
  A[0] = apple(A, n);
}

void kernel __attribute__((reqd_work_group_size(1, 1, 1))) bar(global float* B, uint m)
{
  B[0] = apple(B, m) + apple(B, m+2);
}

// CHECK:  ; SPIR-V
// CHECK:  ; Version: 1.0
// CHECK:  ; Generator: Codeplay; 0
// CHECK:  ; Bound: 50
// CHECK:  ; Schema: 0
// CHECK:  OpCapability Shader
// CHECK:  OpCapability VariablePointers
// CHECK:  OpExtension "SPV_KHR_storage_buffer_storage_class"
// CHECK:  OpExtension "SPV_KHR_variable_pointers"
// CHECK:  OpMemoryModel Logical GLSL450
// CHECK:  OpEntryPoint GLCompute [[_33:%[0-9a-zA-Z_]+]] "foo"
// CHECK:  OpEntryPoint GLCompute [[_40:%[0-9a-zA-Z_]+]] "bar"
// CHECK:  OpExecutionMode [[_33]] LocalSize 1 1 1
// CHECK:  OpExecutionMode [[_40]] LocalSize 1 1 1
// CHECK:  OpSource OpenCL_C 120
// CHECK:  OpDecorate [[__runtimearr_float:%[0-9a-zA-Z_]+]] ArrayStride 4
// CHECK:  OpMemberDecorate [[__struct_3:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpDecorate [[__struct_3]] Block
// CHECK:  OpMemberDecorate [[__struct_6:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpMemberDecorate [[__struct_7:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpDecorate [[__struct_7]] Block
// CHECK:  OpDecorate [[_17:%[0-9a-zA-Z_]+]] DescriptorSet 0
// CHECK:  OpDecorate [[_17]] Binding 0
// CHECK:  OpDecorate [[_18:%[0-9a-zA-Z_]+]] DescriptorSet 0
// CHECK:  OpDecorate [[_18]] Binding 1
// CHECK:  OpDecorate [[__ptr_StorageBuffer_float:%[0-9a-zA-Z_]+]] ArrayStride 4
// CHECK:  [[_float:%[0-9a-zA-Z_]+]] = OpTypeFloat 32
// CHECK:  [[__runtimearr_float]] = OpTypeRuntimeArray [[_float]]
// CHECK:  [[__struct_3]] = OpTypeStruct [[__runtimearr_float]]
// CHECK:  [[__ptr_StorageBuffer__struct_3:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[__struct_3]]
// CHECK:  [[_uint:%[0-9a-zA-Z_]+]] = OpTypeInt 32 0
// CHECK:  [[__struct_6]] = OpTypeStruct [[_uint]]
// CHECK:  [[__struct_7]] = OpTypeStruct [[__struct_6]]
// CHECK:  [[__ptr_StorageBuffer__struct_7:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[__struct_7]]
// CHECK:  [[_void:%[0-9a-zA-Z_]+]] = OpTypeVoid
// CHECK:  [[_10:%[0-9a-zA-Z_]+]] = OpTypeFunction [[_void]]
// CHECK:  [[__ptr_StorageBuffer_float]] = OpTypePointer StorageBuffer [[_float]]
// CHECK:  [[__ptr_StorageBuffer__struct_6:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[__struct_6]]
// CHECK:  [[_13:%[0-9a-zA-Z_]+]] = OpTypeFunction [[_float]] [[__ptr_StorageBuffer_float]] [[_uint]]
// CHECK:  [[_uint_0:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 0
// CHECK:  [[_uint_2:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 2
// CHECK:  [[_uint_1:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 1
// CHECK:  [[_17]] = OpVariable [[__ptr_StorageBuffer__struct_3]] StorageBuffer
// CHECK:  [[_18]] = OpVariable [[__ptr_StorageBuffer__struct_7]] StorageBuffer
// CHECK:  [[_19:%[0-9a-zA-Z_]+]] = OpFunction [[_float]] Pure [[_13]]
// CHECK:  [[_20:%[0-9a-zA-Z_]+]] = OpFunctionParameter [[__ptr_StorageBuffer_float]]
// CHECK:  [[_21:%[0-9a-zA-Z_]+]] = OpFunctionParameter [[_uint]]
// CHECK:  [[_22:%[0-9a-zA-Z_]+]] = OpLabel
// CHECK:  [[_23:%[0-9a-zA-Z_]+]] = OpPtrAccessChain [[__ptr_StorageBuffer_float]] [[_20]] [[_21]]
// CHECK:  [[_24:%[0-9a-zA-Z_]+]] = OpLoad [[_float]] [[_23]]
// CHECK:  OpReturnValue [[_24]]
// CHECK:  OpFunctionEnd
// CHECK:  [[_25:%[0-9a-zA-Z_]+]] = OpFunction [[_float]] Pure [[_13]]
// CHECK:  [[_26:%[0-9a-zA-Z_]+]] = OpFunctionParameter [[__ptr_StorageBuffer_float]]
// CHECK:  [[_27:%[0-9a-zA-Z_]+]] = OpFunctionParameter [[_uint]]
// CHECK:  [[_28:%[0-9a-zA-Z_]+]] = OpLabel
// CHECK:  [[_29:%[0-9a-zA-Z_]+]] = OpFunctionCall [[_float]] [[_19]] [[_26]] [[_27]]
// CHECK:  [[_30:%[0-9a-zA-Z_]+]] = OpIAdd [[_uint]] [[_27]] [[_uint_1]]
// CHECK:  [[_31:%[0-9a-zA-Z_]+]] = OpFunctionCall [[_float]] [[_19]] [[_26]] [[_30]]
// CHECK:  [[_32:%[0-9a-zA-Z_]+]] = OpFAdd [[_float]] [[_29]] [[_31]]
// CHECK:  OpReturnValue [[_32]]
// CHECK:  OpFunctionEnd
// CHECK:  [[_33]] = OpFunction [[_void]] None [[_10]]
// CHECK:  [[_34:%[0-9a-zA-Z_]+]] = OpLabel
// CHECK:  [[_35:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer_float]] [[_17]] [[_uint_0]] [[_uint_0]]
// CHECK:  [[_36:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer__struct_6]] [[_18]] [[_uint_0]]
// CHECK:  [[_37:%[0-9a-zA-Z_]+]] = OpLoad [[__struct_6]] [[_36]]
// CHECK:  [[_38:%[0-9a-zA-Z_]+]] = OpCompositeExtract [[_uint]] [[_37]] 0
// CHECK:  [[_39:%[0-9a-zA-Z_]+]] = OpFunctionCall [[_float]] [[_25]] [[_35]] [[_38]]
// CHECK:  OpStore [[_35]] [[_39]]
// CHECK:  OpReturn
// CHECK:  OpFunctionEnd
// CHECK:  [[_40]] = OpFunction [[_void]] None [[_10]]
// CHECK:  [[_41:%[0-9a-zA-Z_]+]] = OpLabel
// CHECK:  [[_42:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer_float]] [[_17]] [[_uint_0]] [[_uint_0]]
// CHECK:  [[_43:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer__struct_6]] [[_18]] [[_uint_0]]
// CHECK:  [[_44:%[0-9a-zA-Z_]+]] = OpLoad [[__struct_6]] [[_43]]
// CHECK:  [[_45:%[0-9a-zA-Z_]+]] = OpCompositeExtract [[_uint]] [[_44]] 0
// CHECK:  [[_46:%[0-9a-zA-Z_]+]] = OpFunctionCall [[_float]] [[_25]] [[_42]] [[_45]]
// CHECK:  [[_47:%[0-9a-zA-Z_]+]] = OpIAdd [[_uint]] [[_45]] [[_uint_2]]
// CHECK:  [[_48:%[0-9a-zA-Z_]+]] = OpFunctionCall [[_float]] [[_25]] [[_42]] [[_47]]
// CHECK:  [[_49:%[0-9a-zA-Z_]+]] = OpFAdd [[_float]] [[_46]] [[_48]]
// CHECK:  OpStore [[_42]] [[_49]]
// CHECK:  OpReturn
// CHECK:  OpFunctionEnd
