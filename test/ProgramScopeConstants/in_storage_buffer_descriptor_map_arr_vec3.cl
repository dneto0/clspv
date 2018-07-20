// RUN: clspv %s -S -o %t.spvasm -descriptormap=%t.map -module-constants-in-storage-buffer
// RUN: FileCheck %s < %t.spvasm
// RUN: FileCheck -check-prefix=MAP %s < %t.map
// RUN: clspv %s -o %t.spv -descriptormap=%t.map -module-constants-in-storage-buffer
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: FileCheck -check-prefix=MAP %s < %t.map
// RUN: spirv-val --target-env vulkan1.0 %t.spv

// Proves ConstantDataVector and ConstantArray work.

__constant uint3 ppp[2] = {(uint3)(1,2,3), (uint3)(5)};

kernel void foo(global uint* A, uint i) { *A = ppp[i].x; }



// MAP: constant,descriptorSet,0,binding,0,kind,buffer,hexbytes,0100000002000000030000000000000005000000050000000500000000000000
// MAP-NEXT: kernel,foo,arg,A,argOrdinal,0,descriptorSet,1,binding,0,offset,0,argKind,buffer
// MAP-NEXT: kernel,foo,arg,i,argOrdinal,1,descriptorSet,1,binding,1,offset,0,argKind,pod

// CHECK:  ; SPIR-V
// CHECK:  ; Version: 1.0
// CHECK:  ; Generator: Codeplay; 0
// CHECK:  ; Bound: 39
// CHECK:  ; Schema: 0
// CHECK:  OpCapability Shader
// CHECK:  OpCapability VariablePointers
// CHECK:  OpExtension "SPV_KHR_storage_buffer_storage_class"
// CHECK:  OpExtension "SPV_KHR_variable_pointers"
// CHECK:  OpMemoryModel Logical GLSL450
// CHECK:  OpEntryPoint GLCompute [[_31:%[0-9a-zA-Z_]+]] "foo"
// CHECK:  OpSource OpenCL_C 120
// CHECK:  OpDecorate [[_23:%[0-9a-zA-Z_]+]] SpecId 0
// CHECK:  OpDecorate [[_24:%[0-9a-zA-Z_]+]] SpecId 1
// CHECK:  OpDecorate [[_25:%[0-9a-zA-Z_]+]] SpecId 2
// CHECK:  OpDecorate [[__runtimearr_uint:%[0-9a-zA-Z_]+]] ArrayStride 4
// CHECK:  OpMemberDecorate [[__struct_3:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpDecorate [[__struct_3]] Block
// CHECK:  OpMemberDecorate [[__struct_5:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpDecorate [[__struct_5]] Block
// CHECK:  OpDecorate [[_gl_WorkGroupSize:%[0-9a-zA-Z_]+]] BuiltIn WorkgroupSize
// CHECK:  OpDecorate [[_29:%[0-9a-zA-Z_]+]] DescriptorSet 0
// CHECK:  OpDecorate [[_29]] Binding 0
// CHECK:  OpDecorate [[_30:%[0-9a-zA-Z_]+]] DescriptorSet 0
// CHECK:  OpDecorate [[_30]] Binding 1
// CHECK:  OpDecorate [[__arr_v3uint_uint_2:%[0-9a-zA-Z_]+]] ArrayStride 16
// CHECK:  [[_uint:%[0-9a-zA-Z_]+]] = OpTypeInt 32 0
// CHECK:  [[__runtimearr_uint]] = OpTypeRuntimeArray [[_uint]]
// CHECK:  [[__struct_3]] = OpTypeStruct [[__runtimearr_uint]]
// CHECK:  [[__ptr_StorageBuffer__struct_3:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[__struct_3]]
// CHECK:  [[__struct_5]] = OpTypeStruct [[_uint]]
// CHECK:  [[__ptr_StorageBuffer__struct_5:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[__struct_5]]
// CHECK:  [[_void:%[0-9a-zA-Z_]+]] = OpTypeVoid
// CHECK:  [[_8:%[0-9a-zA-Z_]+]] = OpTypeFunction [[_void]]
// CHECK:  [[__ptr_StorageBuffer_uint:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[_uint]]
// CHECK:  [[_v3uint:%[0-9a-zA-Z_]+]] = OpTypeVector [[_uint]] 3
// CHECK:  [[_uint_2:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 2
// CHECK:  [[__arr_v3uint_uint_2]] = OpTypeArray [[_v3uint]] [[_uint_2]]
// CHECK:  [[__ptr_Private__arr_v3uint_uint_2:%[0-9a-zA-Z_]+]] = OpTypePointer Private [[__arr_v3uint_uint_2]]
// CHECK:  [[__ptr_Private_v3uint:%[0-9a-zA-Z_]+]] = OpTypePointer Private [[_v3uint]]
// CHECK:  [[__ptr_StorageBuffer_v3uint:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[_v3uint]]
// CHECK:  [[_uint_0:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 0
// CHECK:  [[_uint_1:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 1
// CHECK:  [[_uint_3:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 3
// CHECK:  [[_19:%[0-9a-zA-Z_]+]] = OpConstantComposite [[_v3uint]] [[_uint_1]] [[_uint_2]] [[_uint_3]]
// CHECK:  [[_uint_5:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 5
// CHECK:  [[_21:%[0-9a-zA-Z_]+]] = OpConstantComposite [[_v3uint]] [[_uint_5]] [[_uint_5]] [[_uint_5]]
// CHECK:  [[_22:%[0-9a-zA-Z_]+]] = OpConstantComposite [[__arr_v3uint_uint_2]] [[_19]] [[_21]]
// CHECK:  [[_23]] = OpSpecConstant [[_uint]] 1
// CHECK:  [[_24]] = OpSpecConstant [[_uint]] 1
// CHECK:  [[_25]] = OpSpecConstant [[_uint]] 1
// CHECK:  [[_gl_WorkGroupSize]] = OpSpecConstantComposite [[_v3uint]] [[_23]] [[_24]] [[_25]]
// CHECK:  [[_27:%[0-9a-zA-Z_]+]] = OpVariable [[__ptr_Private_v3uint]] Private [[_gl_WorkGroupSize]]
// CHECK:  [[_28:%[0-9a-zA-Z_]+]] = OpVariable [[__ptr_Private__arr_v3uint_uint_2]] Private [[_22]]
// CHECK:  [[_29]] = OpVariable [[__ptr_StorageBuffer__struct_3]] StorageBuffer
// CHECK:  [[_30]] = OpVariable [[__ptr_StorageBuffer__struct_5]] StorageBuffer
// CHECK:  [[_31]] = OpFunction [[_void]] None [[_8]]
// CHECK:  [[_32:%[0-9a-zA-Z_]+]] = OpLabel
// CHECK:  [[_33:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer_uint]] [[_29]] [[_uint_0]] [[_uint_0]]
// CHECK:  [[_34:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer_uint]] [[_30]] [[_uint_0]]
// CHECK:  [[_35:%[0-9a-zA-Z_]+]] = OpLoad [[_uint]] [[_34]]
// CHECK:  [[_36:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_Private_v3uint]] [[_28]] [[_35]]
// CHECK:  [[_37:%[0-9a-zA-Z_]+]] = OpLoad [[_v3uint]] [[_36]]
// CHECK:  [[_38:%[0-9a-zA-Z_]+]] = OpCompositeExtract [[_uint]] [[_37]] 0
// CHECK:  OpStore [[_33]] [[_38]]
// CHECK:  OpReturn
// CHECK:  OpFunctionEnd
