#title[
  Advent of Code 2025: Day 2, Part 2
]

= Method 1: Enumerating IDs
Let $ell$ and $u$ be the lower and upper ends of the ID range.
For an ID $n in [ell, u]$, let $
  f(n) = cases(
    n quad "n invalid",
    0 quad "otherwise".)
$
Then, the solution is $F(n) = sum_(n=ell)^u f(n)$.

We can simply enumerate all possible IDs and compute $f(n)$ for each, i.e., check if there are repeated substrings.
To do so, we define
$
  g(n, m, r) = cases(
    n quad "there is a substring" s "of length" m "such that" s^r = n,
    0 quad "otherwise",)
$
which can be computed by enumerating all prefixes of length $m$.
Then, $
  f(n) = max_(m, r) g(n, m, r).
$

== Analysis
// For a substring of length $m$, there can be up to $r <= (log_10 n + 1) / m$ repetitions.
// Since $m >= 2$, we need to check substrings up to length $(log_10 n + 1) / 2 =: b$.
// Total number of checks: $
//   approx& sum_(m=2)^b 10^m (log_10 n + 1) / m \
//   approx& (log_10 n + 1) sum_(m=1)^(b-1) 10^m / m \
//   approx& (log_10 n) / 2 med 10^(b-1) \
//   approx& (log_10 n) / 2 med 10^((log_10 n)/2) \
//   approx& sqrt(n) med (log_10 n) / 2.
// $
We need to check the first $(log_10 n + 1) / 2$ prefixes.
Assuming a check is $cal(O)(log n)$, the total complexity is thus $cal(O)((u - ell) log^2 u)$.
// $cal(O)((u - ell) sqrt(u) log^2 u)$.

= Method 2: Enumerating prefixes
The main disadvantage with Method 1 is the dependence on $u - ell$.
There are only $floor(u slash 10^(ceil((|u|) slash 2))) <= sqrt(u)$ possible prefixes.
Therefore, intuitively, if $u - ell > sqrt(u)$, we should be able to improve by only checking IDs that are indeed repetitions of prefixes.

For any given prefix, we can check in $cal(O)(log^2 u)$ time if any repetition falls within the range $[l, u]$.
However, prefix repetitions are not unique, e.g., $"a"^4 = "aa"^2 = "aaaa"$, so we need to avoid counting duplicates.
The most straight-forward method is to keep a set of seen invalid IDs and to simply skip any IDs if we have come across them before.
A more space-efficient method is to discard prefixes that are themselves repetitions, using the approach from Method 1.
Finally, it is also possible to generate primitive prefixes directly, e.g., via the Fredricksen-Maiorana (FKM) algorithm, but this is probably outside the scope of Advent of Code.

Using the approach of discarding prefixes, we have the pseudo-algorithm
1. $F <- 0$
2. For $s in {1, ..., u slash 10^(ceil(|u| slash 2))}$:
  1. If $s$ valid:
    1. For $r in {2, ..., floor((|u|) / (|s|))}$:
      1. If $l <= s^r <= u$:
        1. $F <- F + s^r$
3. Return $F$

which has complexity $cal(O)(sqrt(u) log^2 u)$.

#pagebreak()

= Appendix
== Square-root upper bound
For a number $n$ with digit degree 2, i.e., $"digits"(n) = "digits"(s)^2$, we have
$
  n
  &= s (10^(|s|) + 1) \
  &= s (sqrt(10^(|n|)) + 1).
$
If it were true that $s > sqrt(n)$, then $
  n > sqrt(n)(sqrt(10^(|n|)) + 1),
$
but we know that $10^(|n|) > n$, so this is a contradiction.
