use nucleo_matcher::Matcher;
use nucleo_matcher::pattern::{Pattern, CaseMatching, Normalization};

fn test() {
    let mut matcher = Matcher::default();
    let pattern = Pattern::parse("test", CaseMatching::Ignore, Normalization::Smart);
    let mut buf = Vec::new();
    let score = pattern.score(nucleo_matcher::Utf32Str::new("test string", &mut buf), &mut matcher);
}
