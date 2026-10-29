extends GutTest
## A slalom board's tail cut-outs (PH16, BoardConfig.cutout_from_tail_m and cutout_depth_m):
## the bottom the water meets is narrower than the deck's outline near the tail.


func _board(from_tail_m: float, depth_m: float) -> BoardConfig:
	var board: BoardConfig = (load("res://config/board_default.tres") as BoardConfig).duplicate() as BoardConfig
	board.cutout_from_tail_m = from_tail_m
	board.cutout_depth_m = depth_m
	return board


func test_without_cut_outs_the_bottom_is_the_outline() -> void:
	var board: BoardConfig = _board(0.0, 0.0)
	for x: float in [0.0, 0.2, 0.5, 1.1, 2.0]:
		assert_eq(board.bottom_width_at(x), board.width_at(x), "at %.1f m" % x)


func test_the_cut_outs_narrow_the_bottom_most_at_the_tail_and_not_at_their_front() -> void:
	var board: BoardConfig = _board(0.45, 0.02)
	assert_almost_eq(board.width_at(0.0) - board.bottom_width_at(0.0), 0.04, 1e-6, "2 cm a side at the tail")
	assert_almost_eq(board.width_at(0.225) - board.bottom_width_at(0.225), 0.02, 1e-6, "half that halfway")
	assert_eq(board.bottom_width_at(0.45), board.width_at(0.45), "nothing at the cut-out's front")
	assert_eq(board.bottom_width_at(1.0), board.width_at(1.0), "nor beyond it")


func test_the_cut_outs_take_area_off_the_bottom() -> void:
	var plain: float = _board(0.0, 0.0).planform_area_m2()
	var cut: float = _board(0.45, 0.02).planform_area_m2()
	# Two triangles of 0.45 m by 0.02 m: 0.009 m2.
	assert_almost_eq(plain - cut, 0.009, 0.0005)
