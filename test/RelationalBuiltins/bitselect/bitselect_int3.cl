// RUN: clspv %target  %s -o %t.spv
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: spirv-val --target-env vulkan1.0 %t.spv

// CHECK-DAG: %[[uint:[0-9a-zA-Z_]+]] = OpTypeInt 32 0
// CHECK-DAG: %[[v3uint:[0-9a-zA-Z_]+]] = OpTypeVector %[[uint]] 3
// CHECK-DAG: %[[uint_4294967295:[0-9a-zA-Z_]+]] = OpConstant %[[uint]] 4294967295
// CHECK-DAG: %[[__original_id_11:[0-9]+]] = OpConstantComposite %[[v3uint]] %[[uint_4294967295]] %[[uint_4294967295]] %[[uint_4294967295]]
// CHECK:     %[[__original_id_20:[0-9]+]] = OpLoad %[[v3uint]]
// CHECK:     %[[__original_id_21:[0-9]+]] = OpLoad %[[v3uint]]
// CHECK:     %[[__original_id_22:[0-9]+]] = OpLoad %[[v3uint]]
// CHECK:     %[[__original_id_23:[0-9]+]] = OpBitwiseXor %[[v3uint]] %[[__original_id_22]] %[[__original_id_11]]
// CHECK:     %[[__original_id_24:[0-9]+]] = OpBitwiseAnd %[[v3uint]] %[[__original_id_20]] %[[__original_id_23]]
// CHECK:     %[[__original_id_25:[0-9]+]] = OpBitwiseAnd %[[v3uint]] %[[__original_id_22]] %[[__original_id_21]]
// CHECK:     %[[__original_id_26:[0-9]+]] = OpBitwiseOr %[[v3uint]] %[[__original_id_24]] %[[__original_id_25]]
// CHECK:     OpStore {{.*}} %[[__original_id_26]]

kernel void __attribute__((reqd_work_group_size(1, 1, 1))) foo(global int3* a, global int3* b, global int3* c)
{
    *a = bitselect(*a, *b, *c);
}

