<?php
require __DIR__ . '/lib.php';
$pdo = db_conn();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$user_lat = isset($input['user_lat']) ? floatval($input['user_lat']) : null;
$user_lng = isset($input['user_lng']) ? floatval($input['user_lng']) : null;
$k = isset($input['k']) ? max(1, min(100, (int)$input['k'])) : 10;
$tags = isset($input['tags']) && is_array($input['tags']) ? $input['tags'] : [];
$category = isset($input['category']) ? trim($input['category']) : (isset($input['type']) ? trim($input['type']) : null);

if ($user_lat === null || $user_lng === null) {
  json_out(['results' => [], 'error' => 'user_lat and user_lng required'], 400);
}

$where = [];
$args = [];
if ($category) {
  $where[] = '(category LIKE :cat OR subcategory LIKE :cat OR JSON_SEARCH(sentiment_tags, "one", :cat2) IS NOT NULL)';
  $args[':cat'] = "%$category%";
  $args[':cat2'] = $category;
}
$whereSql = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

// Pull a pool; sort by name to keep deterministic
$sql = "SELECT * FROM places $whereSql ORDER BY name ASC LIMIT 800";
$stmt = $pdo->prepare($sql);
$stmt->execute($args);
$rows = $stmt->fetchAll();

$tags_norm = array_map(fn($t)=>strtolower(trim((string)$t)), $tags);
$imgStmt = $pdo->prepare('SELECT url FROM place_images WHERE place_id = :pid ORDER BY COALESCE(sort_order,0) ASC');

$scored = [];
foreach ($rows as $r) {
  $lat = floatval($r['lat']);
  $lng = floatval($r['lng']);
  $d = haversine_km($lat, $lng, $user_lat, $user_lng);
  $dist_score = max(0.0, 1.0 - min($d, 20.0)/20.0); // within 20km
  $tag_score = 0.0;
  if (!empty($tags_norm) && !empty($r['sentiment_tags'])) {
    $st = json_decode($r['sentiment_tags'], true) ?: [];
    $set = array_map(fn($x)=>strtolower((string)$x), $st);
    foreach ($tags_norm as $t) {
      if (in_array($t, $set, true)) $tag_score += 0.3;
    }
  }
  $total = $dist_score + $tag_score;
  $imgStmt->execute([':pid' => $r['id']]);
  $imgs = array_map(fn($x)=>$x['url'], $imgStmt->fetchAll());
  $it = place_row_to_json($r, $imgs);
  $it['distance_km'] = round($d, 2);
  $scored[] = [$total, $it];
}

usort($scored, fn($a,$b)=>$b[0] <=> $a[0]);
$results = array_slice(array_map(fn($x)=>$x[1], $scored), 0, $k);
json_out(['results' => $results]);
