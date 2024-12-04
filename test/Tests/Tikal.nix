{
  __functor = _: { context, maybe, Set, test, type, ... }: test {
    inherit context maybe Set type;
  };
}
