function filterEmojis(baseItems, queryStr) {
  let query = queryStr.toLowerCase().trim();
  if (query.length === 0) return [];

  // Cap early during iteration — no need to score thousands then slice.
  const hardCap = 40;
  let results = [];

  for (let i = 0; i < baseItems.length; i++) {
    let item = baseItems[i];
    let search = item.searchString;

    if (!search.includes(query)) continue;

    let displayLower = item.display.toLowerCase();
    // Prefer prefix hits; for 1-char queries only keep those (substring floods).
    let starts = displayLower.startsWith(query);
    if (query.length === 1 && !starts) continue;

    results.push({
      emoji: item.emoji,
      display: item.display,
      category: item.category,
      searchString: search,
      score: starts ? 2 : 1,
    });

    if (results.length >= hardCap * 3) break;
  }

  results.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.display.length - b.display.length;
  });

  return results.slice(0, hardCap);
}

function parseEmojiJson(textBody) {
  let parsedJson = JSON.parse(textBody);
  let dynamicAllItems = [];

  Object.keys(parsedJson).forEach((key) => {
    let tags = parsedJson[key] || [];
    let rawDesc = tags.length > 0 ? tags[0] : "emoji";
    let displayDesc = rawDesc.replace(/_/g, " ");

    dynamicAllItems.push({
      emoji: key,
      display: displayDesc,
      category: "All",
      searchString: (displayDesc + " " + tags.join(" ")).toLowerCase(),
      score: 0,
    });
  });

  return dynamicAllItems;
}

function updateRecents(emojiChar, allItems, recentItems) {
  let itemObj = allItems.find((item) => item.emoji === emojiChar);
  if (!itemObj) return recentItems;

  let newRecents = recentItems.filter((item) => item.emoji !== emojiChar);
  newRecents.unshift(itemObj);

  if (newRecents.length > 100) newRecents.pop();
  return newRecents;
}
