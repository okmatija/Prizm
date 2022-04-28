test :: () {
    #import "Basic"; // @Question: ask about why this works

    print("Running test in %:%\n", #location().fully_pathed_filename, #location().line_number);

    l := Line3.{origin=.{0, 0, 0}, direction=.{0, 0, 1}};
    p := Hyperplane3.{d=10, normal=.{0, 0, 1}};
    intersect, t := find_intersect_line3_plane3(l, p);
    print("%, %, %\n", intersect, t, to_point(l, t));
}

#if 0 {
#run test();
}
