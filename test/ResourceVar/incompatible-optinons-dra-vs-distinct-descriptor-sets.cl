// RUN: not clspv %s -o %t.spv -distinct-kernel-descriptor-sets -direct-resource-access 2>%t.err
// RUN: FileCheck %s < %t.err




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

// CHECK: error: Options -distinct-kernel-descriptor-sets and -direct-resource-access may not be used at the same time
