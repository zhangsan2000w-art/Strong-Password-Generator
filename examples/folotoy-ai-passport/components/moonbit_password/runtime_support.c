#include <stdlib.h>

// MoonBit core 的 panic/abort 路径引用 moonbit_println（宿主运行时由 env.c 提供，
// 内嵌构建的 vendored runtime 不带它）。设备上没有控制台输出，且 abort 只在
// 不可恢复的 bug 路径触发、随后 moonbit_panic() 会终止程序，这里保持空实现。
void moonbit_println(void *str)
{
    (void)str;
}

_Noreturn void moonbit_panic(void)
{
    abort();
}
