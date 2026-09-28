///|
// 原 main/demo_navigation.c 的主机测试逐条搬过来，断言与期望值一一对应，
// 另外补上 count 为 0 和焦点回绕的边界，这两条原 C 测试没覆盖。
test "navigation walks the list, enters and exits" {
  let navigation = DemoNavigation::new(3)

  // UP 从第 0 项回绕到第 2 项。
  let (action, index) = navigation.handle(demo_nav_input_up_click, true)
  @test.assert_eq(action, demo_nav_action_refresh)
  @test.assert_eq(index, 2)
  @test.assert_eq(navigation.selected(), 2)

  // 当前项不可用时 OK 不进入，active 保持 -1。
  let (action, _) = navigation.handle(demo_nav_input_ok_click, false)
  @test.assert_eq(action, demo_nav_action_none)
  @test.assert_eq(navigation.active(), -1)

  // DOWN 从第 2 项回到第 0 项。
  let (action, index) = navigation.handle(demo_nav_input_down_click, true)
  @test.assert_eq(action, demo_nav_action_refresh)
  @test.assert_eq(index, 0)

  // 可用时 OK 进入，返回的 index 是进入项。
  let (action, index) = navigation.handle(demo_nav_input_ok_click, true)
  @test.assert_eq(action, demo_nav_action_enter)
  @test.assert_eq(index, 0)
  @test.assert_eq(navigation.active(), 0)

  // 进入态：其它输入转发给页面，index 仍是进入项。
  let (action, index) = navigation.handle(demo_nav_input_other, true)
  @test.assert_eq(action, demo_nav_action_forward)
  @test.assert_eq(index, 0)

  // 进入态长按 OK 触发退出，active 在 complete_exit 前仍保留。
  let (action, _) = navigation.handle(demo_nav_input_ok_long, true)
  @test.assert_eq(action, demo_nav_action_exit)
  @test.assert_eq(navigation.active(), 0)

  navigation.complete_exit()
  @test.assert_eq(navigation.active(), -1)
}

///|
test "empty list ignores every input" {
  let navigation = DemoNavigation::new(0)
  for
    input in [
      demo_nav_input_up_click, demo_nav_input_down_click, demo_nav_input_ok_click,
      demo_nav_input_ok_long, demo_nav_input_other,
    ] {
    let (action, index) = navigation.handle(input, true)
    @test.assert_eq(action, demo_nav_action_none)
    @test.assert_eq(index, 0)
  }
  @test.assert_eq(navigation.active(), -1)
}

///|
// 每个 count 走满一圈：第 k 步焦点正好是 k % count，回到起点时归零。
test "selected index wraps around the whole list" {
  let mut count = 1
  while count <= 8 {
    let navigation = DemoNavigation::new(count)
    let mut step = 0
    while step < count {
      let (action, index) = navigation.handle(demo_nav_input_down_click, true)
      @test.assert_eq(action, demo_nav_action_refresh)
      @test.assert_eq(index, (step + 1) % count)
      @test.assert_eq(index >= 0, true)
      @test.assert_eq(index < count, true)
      step = step + 1
    }
    @test.assert_eq(navigation.selected(), 0)
    count = count + 1
  }
}

///|
test "single-item list stays on the only entry" {
  let navigation = DemoNavigation::new(1)
  let (action, index) = navigation.handle(demo_nav_input_up_click, true)
  @test.assert_eq(action, demo_nav_action_refresh)
  @test.assert_eq(index, 0)
  let (action, index) = navigation.handle(demo_nav_input_down_click, true)
  @test.assert_eq(action, demo_nav_action_refresh)
  @test.assert_eq(index, 0)
}
