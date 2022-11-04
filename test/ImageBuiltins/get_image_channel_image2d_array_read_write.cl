
// RUN: clspv %target %s -o %t.spv -cl-std=CL2.0 -inline-entry-points
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: spirv-val --target-env vulkan1.0 %t.spv

// AUTO-GENERATED TEST FILE
// This test was generated by get_image_channel_test_gen.py.
// Please modify that file and regenate the tests to make changes.

void kernel order(global int *dst, image2d_array_t read_write image) {
    *dst = get_image_channel_order(image);
}

void kernel data_type(global int *dst, image2d_array_t read_write image) {
    *dst = get_image_channel_data_type(image);
}

// CHECK: OpMemberDecorate [[struct:%[^ ]+]] 0 Offset 0
// CHECK: OpMemberDecorate [[pc_struct:%[^ ]+]] 0 Offset 0
// CHECK: OpDecorate [[pc_struct]] Block

// CHECK: [[struct]] = OpTypeStruct %uint
// CHECK: [[pc_struct]] = OpTypeStruct [[struct]]
// CHECK: [[ptr_pc_struct:%[^ ]+]] = OpTypePointer PushConstant [[pc_struct]]
// CHECK: [[pc:%[^ ]+]] = OpVariable [[ptr_pc_struct]] PushConstant

// CHECK: [[order_fct:%[^ ]+]] = OpFunction
// CHECK: [[gep:%[^ ]+]] = OpAccessChain {{.*}} [[pc]] %uint_0 %uint_0
// CHECK: [[load:%[^ ]+]] = OpLoad %uint [[gep]]
// CHECK: OpStore {{.*}} [[load]]
// CHECK: OpFunctionEnd

// CHECK: [[data_type_fct:%[^ ]+]] = OpFunction
// CHECK: [[gep:%[^ ]+]] = OpAccessChain {{.*}} [[pc]] %uint_0 %uint_0
// CHECK: [[load:%[^ ]+]] = OpLoad %uint [[gep]]
// CHECK: OpStore {{.*}} [[load]]
// CHECK: OpFunctionEnd

// CHECK: [[order_kernel:%[^ ]+]] = OpExtInst %void {{.*}} Kernel [[order_fct]]
// CHECK: ImageArgumentInfoChannelOrderPushConstant [[order_kernel]] %uint_1 %uint_0 %uint_4
// CHECK: [[data_type_kernel:%[^ ]+]] = OpExtInst %void {{.*}} Kernel [[data_type_fct]]
// CHECK: ImageArgumentInfoChannelDataTypePushConstant [[data_type_kernel]] %uint_1 %uint_0 %uint_4
