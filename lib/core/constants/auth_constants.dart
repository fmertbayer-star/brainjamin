/// Minimum password length for Brainjamin email sign-up.
/// Stricter than Firebase's default of 6. Aligns with NIST 2024
/// guidance and PR-15 in BRAINJAMIN_RULES.md.
class BrainjaminAuthConstants {
  BrainjaminAuthConstants._();

  static const int minPasswordLength = 8;
}
