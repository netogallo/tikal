{
  __functor = _: { context, maybe, test, type, ... }: test {
    inherit context maybe type;
  };
}
