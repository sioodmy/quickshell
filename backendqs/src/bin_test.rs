use nucleo_matcher::Matcher;
use nucleo_matcher::pattern::{Pattern, CaseMatching, Normalization};

fn main() {
    let mut matcher = Matcher::default();
    let pattern = Pattern::parse("query", CaseMatching::Ignore, Normalization::Smart);
    let mut buf = Vec::new();
    let haystack = nucleo_matcher::Utf32Str::new("my_query_string", &mut buf);
    let score = pattern.score(haystack, &mut matcher);
    println!("Score: {:?}", score);
}
