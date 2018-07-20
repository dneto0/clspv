// RUN: clspv %s -S -o %t.spvasm -descriptormap=%t.map -module-constants-in-storage-buffer
// RUN: FileCheck %s < %t.spvasm
// RUN: FileCheck -check-prefix=MAP %s < %t.map
// RUN: clspv %s -o %t.spv -descriptormap=%t.map -module-constants-in-storage-buffer
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: FileCheck -check-prefix=MAP %s < %t.map
// RUN: spirv-val --target-env vulkan1.0 %t.spv

typedef struct {
  char c;
  uint a;
  float f;
} Foo;
__constant Foo ppp[3] = {{'a', 0x1234abcd, 1.0}, {'b', 0xffffffff, 1.5}, {0}};

kernel void foo(global uint* A, uint i) { *A = ppp[i].a; }

// MAP: constant,descriptorSet,0,binding,0,kind,buffer,hexbytes,61000000cdab34120000803f62000000ffffffff0000c03f000000000000000000000000
// MAP-NEXT: kernel,foo,arg,A,argOrdinal,0,descriptorSet,1,binding,0,offset,0,argKind,buffer
// MAP-NEXT: kernel,foo,arg,i,argOrdinal,1,descriptorSet,1,binding,1,offset,0,argKind,pod


// CHECK:  ; SPIR-V
// CHECK:  ; Version: 1.0
// CHECK:  ; Generator: Codeplay; 0
// CHECK:  ; Bound: 45
// CHECK:  ; Schema: 0
// CHECK:  OpCapability Shader
// CHECK:  OpCapability VariablePointers
// CHECK:  OpExtension "SPV_KHR_storage_buffer_storage_class"
// CHECK:  OpExtension "SPV_KHR_variable_pointers"
// CHECK:  OpMemoryModel Logical GLSL450
// CHECK:  OpEntryPoint GLCompute [[_38:%[0-9a-zA-Z_]+]] "foo"
// CHECK:  OpSource OpenCL_C 120
// CHECK:  OpDecorate [[_30:%[0-9a-zA-Z_]+]] SpecId 0
// CHECK:  OpDecorate [[_31:%[0-9a-zA-Z_]+]] SpecId 1
// CHECK:  OpDecorate [[_32:%[0-9a-zA-Z_]+]] SpecId 2
// CHECK:  OpDecorate [[__runtimearr_uint:%[0-9a-zA-Z_]+]] ArrayStride 4
// CHECK:  OpMemberDecorate [[__struct_3:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpDecorate [[__struct_3]] Block
// CHECK:  OpMemberDecorate [[__struct_5:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpDecorate [[__struct_5]] Block
// CHECK:  OpMemberDecorate [[__struct_11:%[0-9a-zA-Z_]+]] 0 Offset 0
// CHECK:  OpMemberDecorate [[__struct_11]] 1 Offset 4
// CHECK:  OpMemberDecorate [[__struct_11]] 2 Offset 8
// CHECK:  OpDecorate [[_gl_WorkGroupSize:%[0-9a-zA-Z_]+]] BuiltIn WorkgroupSize
// CHECK:  OpDecorate [[_36:%[0-9a-zA-Z_]+]] DescriptorSet 0
// CHECK:  OpDecorate [[_36]] Binding 0
// CHECK:  OpDecorate [[_37:%[0-9a-zA-Z_]+]] DescriptorSet 0
// CHECK:  OpDecorate [[_37]] Binding 1
// CHECK:  OpDecorate [[__arr__struct_11_uint_3:%[0-9a-zA-Z_]+]] ArrayStride 12
// CHECK:  [[_uint:%[0-9a-zA-Z_]+]] = OpTypeInt 32 0
// CHECK:  [[__runtimearr_uint]] = OpTypeRuntimeArray [[_uint]]
// CHECK:  [[__struct_3]] = OpTypeStruct [[__runtimearr_uint]]
// CHECK:  [[__ptr_StorageBuffer__struct_3:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[__struct_3]]
// CHECK:  [[__struct_5]] = OpTypeStruct [[_uint]]
// CHECK:  [[__ptr_StorageBuffer__struct_5:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[__struct_5]]
// CHECK:  [[_void:%[0-9a-zA-Z_]+]] = OpTypeVoid
// CHECK:  [[_8:%[0-9a-zA-Z_]+]] = OpTypeFunction [[_void]]
// CHECK:  [[__ptr_StorageBuffer_uint:%[0-9a-zA-Z_]+]] = OpTypePointer StorageBuffer [[_uint]]
// CHECK:  [[_float:%[0-9a-zA-Z_]+]] = OpTypeFloat 32
// CHECK:  [[__struct_11]] = OpTypeStruct [[_uint]] [[_uint]] [[_float]]
// CHECK:  [[_uint_3:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 3
// CHECK:  [[__arr__struct_11_uint_3]] = OpTypeArray [[__struct_11]] [[_uint_3]]
// CHECK:  [[__ptr_Private__arr__struct_11_uint_3:%[0-9a-zA-Z_]+]] = OpTypePointer Private [[__arr__struct_11_uint_3]]
// CHECK:  [[__ptr_Private_uint:%[0-9a-zA-Z_]+]] = OpTypePointer Private [[_uint]]
// CHECK:  [[_v3uint:%[0-9a-zA-Z_]+]] = OpTypeVector [[_uint]] 3
// CHECK:  [[__ptr_Private_v3uint:%[0-9a-zA-Z_]+]] = OpTypePointer Private [[_v3uint]]
// CHECK:  [[_uint_0:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 0
// CHECK:  [[_uint_1:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 1
// CHECK:  [[_uint_97:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 97
// CHECK:  [[_uint_305441741:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 305441741
// CHECK:  [[_float_1:%[0-9a-zA-Z_]+]] = OpConstant [[_float]] 1
// CHECK:  [[_23:%[0-9a-zA-Z_]+]] = OpConstantComposite [[__struct_11]] [[_uint_97]] [[_uint_305441741]] [[_float_1]]
// CHECK:  [[_uint_98:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 98
// CHECK:  [[_uint_4294967295:%[0-9a-zA-Z_]+]] = OpConstant [[_uint]] 4294967295
// CHECK:  [[_float_1_5:%[0-9a-zA-Z_]+]] = OpConstant [[_float]] 1.5
// CHECK:  [[_27:%[0-9a-zA-Z_]+]] = OpConstantComposite [[__struct_11]] [[_uint_98]] [[_uint_4294967295]] [[_float_1_5]]
// CHECK:  [[_28:%[0-9a-zA-Z_]+]] = OpConstantNull [[__struct_11]]
// CHECK:  [[_29:%[0-9a-zA-Z_]+]] = OpConstantComposite [[__arr__struct_11_uint_3]] [[_23]] [[_27]] [[_28]]
// CHECK:  [[_30]] = OpSpecConstant [[_uint]] 1
// CHECK:  [[_31]] = OpSpecConstant [[_uint]] 1
// CHECK:  [[_32]] = OpSpecConstant [[_uint]] 1
// CHECK:  [[_gl_WorkGroupSize]] = OpSpecConstantComposite [[_v3uint]] [[_30]] [[_31]] [[_32]]
// CHECK:  [[_34:%[0-9a-zA-Z_]+]] = OpVariable [[__ptr_Private_v3uint]] Private [[_gl_WorkGroupSize]]
// CHECK:  [[_35:%[0-9a-zA-Z_]+]] = OpVariable [[__ptr_Private__arr__struct_11_uint_3]] Private [[_29]]
// CHECK:  [[_36]] = OpVariable [[__ptr_StorageBuffer__struct_3]] StorageBuffer
// CHECK:  [[_37]] = OpVariable [[__ptr_StorageBuffer__struct_5]] StorageBuffer
// CHECK:  [[_38]] = OpFunction [[_void]] None [[_8]]
// CHECK:  [[_39:%[0-9a-zA-Z_]+]] = OpLabel
// CHECK:  [[_40:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer_uint]] [[_36]] [[_uint_0]] [[_uint_0]]
// CHECK:  [[_41:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_StorageBuffer_uint]] [[_37]] [[_uint_0]]
// CHECK:  [[_42:%[0-9a-zA-Z_]+]] = OpLoad [[_uint]] [[_41]]
// CHECK:  [[_43:%[0-9a-zA-Z_]+]] = OpAccessChain [[__ptr_Private_uint]] [[_35]] [[_42]] [[_uint_1]]
// CHECK:  [[_44:%[0-9a-zA-Z_]+]] = OpLoad [[_uint]] [[_43]]
// CHECK:  OpStore [[_40]] [[_44]]
// CHECK:  OpReturn
// CHECK:  OpFunctionEnd
