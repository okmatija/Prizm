Fraction :: struct {
    numer : int;
    denom : int;
}

operator== :: (a : Fraction, b : Fraction) -> bool {
    return a.numer == b.numer && a.denom == b.denom;
}

