extends GutTest
## The start menu's "Play with a friend" page (LanPage): it builds, offers a name, and its host's
## choices become the game the guest is sent (LAN multiplayer, Documentation/reports/multiplayer/PLAN.md).
## Hosting itself opens a port, so these tests stay on the start view and the choices.

var _page: LanPage = null


func before_each() -> void:
	_page = (load("res://ui/lan_page.tscn") as PackedScene).instantiate() as LanPage
	add_child_autofree(_page)


func after_each() -> void:
	Lan.leave()


func test_the_page_opens_on_the_start_view_with_a_name() -> void:
	assert_eq(_page._view, LanPage.View.START)
	assert_true(_page._start_box.visible)
	assert_false(_page._join_box.visible)
	assert_false(_page._lobby_box.visible)
	assert_ne(_page._name_edit.text, "", "a name to start with")


func test_the_course_list_follows_the_water() -> void:
	LanPage.chosen_lake = false
	_page._fill_courses()
	assert_eq(_page._course_names[0], RaceCourses.T1_NAME, "T1 first on the open water")
	LanPage.chosen_lake = true
	_page._fill_courses()
	assert_eq(_page._course_names[0], RaceCourses.T2_NAME, "T2 first on the lake")
	LanPage.chosen_lake = false


func test_the_lake_time_is_found_back_from_its_seconds() -> void:
	assert_eq(LanPage._lake_time_index(14.5 * 3600.0), 1)
	assert_eq(LanPage._lake_time_index(17.0 * 3600.0), 2)
	assert_eq(LanPage._lake_time_index(3.0 * 3600.0), 1, "an unknown time shows as 14:30")


func test_the_race_page_and_the_lobby_offer_the_same_courses() -> void:
	var open: Array[PackedStringArray] = RacePage.course_choices(false)
	assert_eq(open[0].size(), open[1].size(), "a title per course")
	assert_gt(open[0].size(), 1, "T1 and the templates")
