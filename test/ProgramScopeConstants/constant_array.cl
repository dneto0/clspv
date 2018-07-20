// RUN: clspv %s -S -o %t.spvasm
// RUN: FileCheck %s < %t.spvasm
// RUN: clspv %s -o %t.spv
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: spirv-val --target-env vulkan1.0 %t.spv

// CHECK: ; SPIR-V
// CHECK: ; Version: 1.0
// CHECK: ; Generator: Codeplay; 0
// CHECK: ; Bound: 30
// CHECK: ; Schema: 0
// CHECK: OpCapability Shader
// CHECK: OpCapability VariablePointers
// CHECK: OpExtension "SPV_KHR_variable_pointers"
// CHECK: OpMemoryModel Logical GLSL450
// CHECK: OpEntryPoint GLCompute %[[FOO_ID:[a-zA-Z0-9_]*]] "foo" %[[BUILTIN_ID:[a-zA-Z0-9_]*]]
// CHECK: OpExecutionMode %[[FOO_ID]] LocalSize 4 1 1
// CHECK: OpDecorate %[[UINT_DYNAMIC_ARRAY_TYPE_ID:[a-zA-Z0-9_]*]] ArrayStride 4
// CHECK: OpMemberDecorate %[[UINT_ARG_STRUCT_TYPE_ID:[a-zA-Z0-9_]*]] 0 Offset 0
// CHECK: OpDecorate %[[UINT_ARG_STRUCT_TYPE_ID]] Block
// CHECK: OpDecorate %[[BUILTIN_ID]] BuiltIn LocalInvocationId
// CHECK: OpDecorate %[[ARG0_ID:[a-zA-Z0-9_]*]] DescriptorSet 0
// CHECK: OpDecorate %[[ARG0_ID]] Binding 0
// CHECK-DAG: %[[UINT_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypeInt 32 0
// CHECK-DAG: %[[UINT_GLOBAL_POINTER_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypePointer StorageBuffer %[[UINT_TYPE_ID]]
// CHECK-DAG: %[[UINT_DYNAMIC_ARRAY_TYPE_ID]] = OpTypeRuntimeArray %[[UINT_TYPE_ID]]
// CHECK-DAG: %[[UINT_ARG_STRUCT_TYPE_ID]] = OpTypeStruct %[[UINT_DYNAMIC_ARRAY_TYPE_ID]]
// CHECK-DAG: %[[UINT_ARG_POINTER_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypePointer StorageBuffer %[[UINT_ARG_STRUCT_TYPE_ID]]
// CHECK-DAG: %[[VOID_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypeVoid
// CHECK-DAG: %[[FOO_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypeFunction %[[VOID_TYPE_ID]]
// CHECK-DAG: %[[UINT3_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypeVector %[[UINT_TYPE_ID]] 3
// CHECK-DAG: %[[UINT3_INPUT_POINTER_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypePointer Input %[[UINT3_TYPE_ID]]
// CHECK-DAG: %[[UINT_INPUT_POINTER_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypePointer Input %[[UINT_TYPE_ID]]
// CHECK-DAG: %[[CONSTANT_4_ID:[a-zA-Z0-9_]*]] = OpConstant %[[UINT_TYPE_ID]] 4
// CHECK-DAG: %[[B_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypeArray %[[UINT_TYPE_ID]] %[[CONSTANT_4_ID]]
// CHECK-DAG: %[[B_POINTER_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypePointer Private %[[B_TYPE_ID]]
// CHECK-DAG: %[[UINT_PRIVATE_POINTER_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypePointer Private %[[UINT_TYPE_ID]]

// CHECK-DAG: %[[CONSTANT_0_ID:[a-zA-Z0-9_]*]] = OpConstant %[[UINT_TYPE_ID]] 0
// CHECK-DAG: %[[CONSTANT_42_ID:[a-zA-Z0-9_]*]] = OpConstant %[[UINT_TYPE_ID]] 42
// CHECK-DAG: %[[CONSTANT_13_ID:[a-zA-Z0-9_]*]] = OpConstant %[[UINT_TYPE_ID]] 13
// CHECK-DAG: %[[CONSTANT_5_ID:[a-zA-Z0-9_]*]] = OpConstant %[[UINT_TYPE_ID]] 5
// CHECK-DAG: %[[CONSTANT_B_ID:[a-zA-Z0-9_]*]] = OpConstantComposite %[[B_TYPE_ID]] %[[CONSTANT_42_ID]] %[[CONSTANT_13_ID]] %[[CONSTANT_0_ID]] %[[CONSTANT_5_ID]]

// CHECK: %[[BUILTIN_ID]] = OpVariable %[[UINT3_INPUT_POINTER_TYPE_ID]] Input
// CHECK: %[[B_ID:[a-zA-Z0-9_]*]] = OpVariable %[[B_POINTER_TYPE_ID]] Private %[[CONSTANT_B_ID]]

constant uint b[4] = {42, 13, 0, 5};

// CHECK: %[[ARG0_ID]] = OpVariable %[[UINT_ARG_POINTER_TYPE_ID]] StorageBuffer

// CHECK: %[[FOO_ID]] = OpFunction %[[VOID_TYPE_ID]] None %[[FOO_TYPE_ID]]
// CHECK: %[[FOO_LABEL_ID:[a-zA-Z0-9_]*]] = OpLabel
// CHECK: %[[A_ACCESS_CHAIN_ID:[a-zA-Z0-9_]*]] = OpAccessChain %[[UINT_GLOBAL_POINTER_TYPE_ID]] %[[ARG0_ID]] %[[CONSTANT_0_ID]] %[[CONSTANT_0_ID]]

// CHECK: %[[BUILTIN_ACCESS_CHAIN_ID:[a-zA-Z0-9_]*]] = OpAccessChain %[[UINT_INPUT_POINTER_TYPE_ID]] %[[BUILTIN_ID]] %[[CONSTANT_0_ID]]
// CHECK: %[[LOCAL_X_ID:[a-zA-Z0-9_]*]] = OpLoad %[[UINT_TYPE_ID]] %[[BUILTIN_ACCESS_CHAIN_ID]]

// CHECK: %[[B_ACCESS_CHAIN_ID:[a-zA-Z0-9_]*]] = OpAccessChain %[[UINT_PRIVATE_POINTER_TYPE_ID]] %[[B_ID]] %[[LOCAL_X_ID]]
// CHECK: %[[RESULT_ID:[a-zA-Z0-9_]*]] = OpLoad %[[UINT_TYPE_ID]] %[[B_ACCESS_CHAIN_ID]]

// CHECK: OpStore %[[A_ACCESS_CHAIN_ID]] %[[RESULT_ID]]
// CHECK: OpReturn
// CHECK: OpFunctionEnd

void kernel __attribute__((reqd_work_group_size(4, 1, 1))) foo(global uint* a)
{
  *a = b[get_local_id(0)];
}
