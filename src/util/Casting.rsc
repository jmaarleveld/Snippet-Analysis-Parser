module util::Casting


public &T cast(type[&T] tp, value v) throws str {
    if (&T tv := v)
        return tv;
    else
        throw "cast failed";
}
