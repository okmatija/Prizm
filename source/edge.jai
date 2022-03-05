Edge :: struct ($Point : Type) {
    from_point : *Point;
    to_point   : *Point;
}

Edge2 :: Edge(Vector2);
Edge3 :: Edge(Vector3);

Indexed_Edge :: struct ($_Point : Type) {
    using edge : Edge(_Point);

    from_index : int = ---;
    to_index   : int = ---;
}

Indexed_Edge2 :: Indexed_Edge(Vector2);
Indexed_Edge3 :: Indexed_Edge(Vector3);