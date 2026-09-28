///|
// 演示页导航状态机。原先在 main/demo_navigation.c：一个 demo_* 演示页共享的
// 纯逻辑，宿主 C 测试直接编译它（demo_* 系列并没有编进 main/CMakeLists，所以它
// 当时也只剩下这条测试在用）。它不碰 LVGL/GPIO，属于典型的“决策写在 C 里”，
// 因此整体搬进 MoonBit 核心，语义与断言逐条对齐原实现。
//
// 浏览态：UP/DOWN 在 count 项之间循环，返回 REFRESH；OK 在当前项可用时进入，
// 返回 ENTER。进入态（active >= 0）：除长按 OK 退出外，其余输入一律 FORWARD
// 给已进入的页面。count 为 0 时任何输入都得到 NONE。

///|
pub let demo_nav_action_none : Int = 0

///|
pub let demo_nav_action_refresh : Int = 1

///|
pub let demo_nav_action_enter : Int = 2

///|
pub let demo_nav_action_exit : Int = 3

///|
pub let demo_nav_action_forward : Int = 4

///|
pub let demo_nav_input_other : Int = 0

///|
pub let demo_nav_input_up_click : Int = 1

///|
pub let demo_nav_input_down_click : Int = 2

///|
pub let demo_nav_input_ok_click : Int = 3

///|
pub let demo_nav_input_ok_long : Int = 4

///|
pub struct DemoNavigation {
  mut selected : Int
  mut active : Int
  count : Int
}

///|
// 新建导航：焦点停在第 0 项，未进入任何页面（active = -1）。
pub fn DemoNavigation::new(count : Int) -> DemoNavigation {
  { selected: 0, active: -1, count, }
}

///|
// 处理一次输入，返回 (action, index)。index 在浏览态是当前焦点，
// 在进入态是已进入的页面下标。
pub fn DemoNavigation::handle(
  self : DemoNavigation,
  input : Int,
  selected_available : Bool,
) -> (Int, Int) {
  if self.count <= 0 {
    return (demo_nav_action_none, 0)
  }
  if self.active >= 0 {
    let action = if input == demo_nav_input_ok_long {
      demo_nav_action_exit
    } else {
      demo_nav_action_forward
    }
    return (action, self.active)
  }
  let mut action = demo_nav_action_none
  if input == demo_nav_input_up_click {
    self.selected = (self.selected + self.count - 1) % self.count
    action = demo_nav_action_refresh
  } else if input == demo_nav_input_down_click {
    self.selected = (self.selected + 1) % self.count
    action = demo_nav_action_refresh
  } else if input == demo_nav_input_ok_click && selected_available {
    self.active = self.selected
    action = demo_nav_action_enter
  }
  (action, self.selected)
}

///|
// 页面退出流程走完后清掉进入态，回到浏览态。
pub fn DemoNavigation::complete_exit(self : DemoNavigation) -> Unit {
  self.active = -1
}

///|
pub fn DemoNavigation::selected(self : DemoNavigation) -> Int {
  self.selected
}

///|
pub fn DemoNavigation::active(self : DemoNavigation) -> Int {
  self.active
}
