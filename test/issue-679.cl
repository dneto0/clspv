// RUN: clspv %target %s -o %t2.spv -arch=spir
// RUN: spirv-dis -o %t2.spvasm %t2.spv
// RUN: FileCheck %s < %t2.spvasm --check-prefixes=CHECK,CHECK-32
// RUN: spirv-val --target-env vulkan1.0 %t2.spv

// RUN: clspv %target %s -o %t2.spv -arch=spir64
// RUN: spirv-dis -o %t2.spvasm %t2.spv
// RUN: FileCheck %s < %t2.spvasm --check-prefixes=CHECK,CHECK-64
// RUN: spirv-val --target-env vulkan1.0 %t2.spv

// CHECK-DAG: [[uint:%[0-9a-zA-Z_]*]] = OpTypeInt 32
// CHECK-64-DAG: [[ulong:%[0-9a-zA-Z_]*]] = OpTypeInt 64
// CHECK-DAG: [[uint_0:%[0-9a-zA-Z_]*]] = OpConstant [[uint]] 0
// CHECK-DAG: [[uint_1:%[0-9a-zA-Z_]*]] = OpConstant [[uint]] 1
// CHECK-DAG: [[uint_2:%[0-9a-zA-Z_]*]] = OpConstant [[uint]] 2
// CHECK-32-DAG: [[uint_3:%[0-9a-zA-Z_]*]] = OpConstant [[uint]] 3
// CHECK-64-DAG: [[ulong_1:%[0-9a-zA-Z_]*]] = OpConstant [[ulong]] 1
// CHECK-64-DAG: [[ulong_2:%[0-9a-zA-Z_]*]] = OpConstant [[ulong]] 2
// CHECK-64-DAG: [[ulong_3:%[0-9a-zA-Z_]*]] = OpConstant [[ulong]] 3
// CHECK-DAG: [[float:%[0-9a-zA-Z_]*]] = OpTypeFloat 32
// CHECK-32: [[in_mul:%[0-9a-zA-Z_]*]] = OpIMul [[uint]] {{.*}} [[uint_3]]
// CHECK-64: [[in_mul:%[0-9a-zA-Z_]*]] = OpIMul [[ulong]] {{.*}} [[ulong_3]]
// CHECK-32: [[load0_shift:%[0-9a-zA-Z_]*]] = OpShiftRightLogical [[uint]] [[in_mul]] [[uint_2]]
// CHECK-64: [[load0_shift:%[0-9a-zA-Z_]*]] = OpShiftRightLogical [[ulong]] [[in_mul]] [[ulong_2]]
// CHECK-32: [[load0_idx:%[0-9a-zA-Z_]*]] = OpBitwiseAnd [[uint]] [[in_mul]] [[uint_3]]
// CHECK-64: [[load0_idx:%[0-9a-zA-Z_]*]] = OpBitwiseAnd [[ulong]] [[in_mul]] [[ulong_3]]
// CHECK: [[load0_addr:%[0-9a-zA-Z_]*]] = OpAccessChain {{.*}} [[uint_0]] [[load0_shift]] [[load0_idx]]
// CHECK: [[x0:%[0-9a-zA-Z_]*]] = OpLoad [[float]] [[load0_addr]]
// CHECK-32: [[load1_offset:%[0-9a-zA-Z_]*]] = OpIAdd [[uint]] [[in_mul]] [[uint_1]]
// CHECK-64: [[load1_offset:%[0-9a-zA-Z_]*]] = OpIAdd [[ulong]] [[in_mul]] [[ulong_1]]
// CHECK-32: [[load1_shift:%[0-9a-zA-Z_]*]] = OpShiftRightLogical [[uint]] [[load1_offset]] [[uint_2]]
// CHECK-64: [[load1_shift:%[0-9a-zA-Z_]*]] = OpShiftRightLogical [[ulong]] [[load1_offset]] [[ulong_2]]
// CHECK-32: [[load1_idx:%[0-9a-zA-Z_]*]] = OpBitwiseAnd [[uint]] [[load1_offset]] [[uint_3]]
// CHECK-64: [[load1_idx:%[0-9a-zA-Z_]*]] = OpBitwiseAnd [[ulong]] [[load1_offset]] [[ulong_3]]
// CHECK: [[load1_addr:%[0-9a-zA-Z_]*]] = OpAccessChain {{.*}} [[uint_0]] [[load1_shift]] [[load1_idx]]
// CHECK: [[x1:%[0-9a-zA-Z_]*]] = OpLoad [[float]] [[load1_addr]]
// CHECK-32: [[load2_offset:%[0-9a-zA-Z_]*]] = OpIAdd [[uint]] [[in_mul]] [[uint_2]]
// CHECK-64: [[load2_offset:%[0-9a-zA-Z_]*]] = OpIAdd [[ulong]] [[in_mul]] [[ulong_2]]
// CHECK-32: [[load2_shift:%[0-9a-zA-Z_]*]] = OpShiftRightLogical [[uint]] [[load2_offset]] [[uint_2]]
// CHECK-64: [[load2_shift:%[0-9a-zA-Z_]*]] = OpShiftRightLogical [[ulong]] [[load2_offset]] [[ulong_2]]
// CHECK-32: [[load2_idx:%[0-9a-zA-Z_]*]] = OpBitwiseAnd [[uint]] [[load2_offset]] [[uint_3]]
// CHECK-64: [[load2_idx:%[0-9a-zA-Z_]*]] = OpBitwiseAnd [[ulong]] [[load2_offset]] [[ulong_3]]
// CHECK: [[load2_addr:%[0-9a-zA-Z_]*]] = OpAccessChain {{.*}} [[uint_0]] [[load2_shift]] [[load2_idx]]
// CHECK: [[x2:%[0-9a-zA-Z_]*]] = OpLoad [[float]] [[load2_addr]]
// CHECK: [[x10:%[0-9a-zA-Z_]*]] = OpFAdd [[float]] [[x0]] [[x1]]
// CHECK: [[StoreVal:%[0-9a-zA-Z_]*]] = OpFAdd [[float]] [[x10]] [[x2]]
// CHECK: [[StoreAddr:%[0-9a-zA-Z_]*]] = OpAccessChain
// CHECK: OpStore [[StoreAddr]] [[StoreVal]]

kernel void test(global float *out, global float3 *in) {
  uint gid = get_global_id(0);
  float3 x = vload3(gid, (global float *)in);
  out[gid] = x[0] + x[1] + x[2];
}
