#include "ui_text.h"

#include <stddef.h>
#include <string.h>

#include "moonbit_password.h"

/*
 * 界面文案共享缓冲。moonbit/ui_text.mbt 与 moonbit/status_text.mbt 都把 UTF-8
 * 字节经下面四个回调写进来：两份文案从不同时使用，因此共用一块 64 字节缓冲。
 */
#define UI_TEXT_MAX 64
static char s_ui_text[UI_TEXT_MAX];

void passport_ui_text_reset(void)
{
    s_ui_text[0] = '\0';
}

int32_t passport_ui_text_push(int32_t ch)
{
    if (ch < 1 || ch > 255) return 0;
    const size_t length = strlen(s_ui_text);
    if (length + 1 >= sizeof(s_ui_text)) return 0;
    s_ui_text[length] = (char)ch;
    s_ui_text[length + 1] = '\0';
    return 1;
}

/* status_text.mbt 复用同一块缓冲，语义与 ui_text 一致。 */
void passport_status_text_reset(void)
{
    s_ui_text[0] = '\0';
}

int32_t passport_status_text_push(int32_t ch)
{
    return passport_ui_text_push(ch);
}

const char *ui_text_collected(int32_t built_bytes)
{
    if (built_bytes <= 0) return NULL;
    if ((size_t)built_bytes != strlen(s_ui_text)) return NULL;
    return s_ui_text;
}

const char *ui_text(int kind, int a, int b)
{
    return ui_text_collected(passport_moonbit_ui_text_build(kind, a, b));
}

const char *ui_text_diagnostic_detail(int status, int completed, int target,
                                      int passed, int failure)
{
    return ui_text_collected(passport_moonbit_diagnostic_detail_build(
        status, completed, target, passed, failure));
}
