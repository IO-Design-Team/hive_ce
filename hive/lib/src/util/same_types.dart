/// Whether two types are the same type.
///
/// Uses the same definition as the language specification for when
/// two types are the same.
/// Currently the same as mutual subtyping.
bool sameTypes<S, T>() {
  void func<X extends S>() {}
  // Spec says this is only true if S and T are "the same type".
  return func is void Function<X extends T>();
}
