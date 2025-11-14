<?php
require __DIR__ . '/lib.php';
$pdo = db_conn();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$q = isset($input['query']) ? trim($input['query']) : '';
$k = isset($input['k']) ? max(1, min(100, (int)$input['k'])) : 10;
$category = isset($input['type']) ? trim($input['type']) : (isset($input['category']) ? trim($input['category']) : null);

$where = [];
$args = [];
if ($q !== '') {
  $where[] = '(name LIKE :q OR description LIKE :q OR category LIKE :q OR subcategory LIKE :q)';
  $args[':q'] = "%$q%";
}
if ($category) {
  $where[] = '(category LIKE :cat OR subcategory LIKE :cat OR JSON_SEARCH(sentiment_tags, "one", :cat2) IS NOT NULL)';
  $args[':cat'] = "%$category%";
  $args[':cat2'] = $category;
}
$whereSql = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

$sql = "SELECT * FROM places $whereSql ORDER BY name ASC LIMIT :lim";
$stmt = $pdo->prepare($sql);
foreach ($args as $k2=>$v) { $stmt->bindValue($k2, $v); }
$stmt->bindValue(':lim', $k, PDO::PARAM_INT);
$stmt->execute();
$rows = $stmt->fetchAll();

$imgStmt = $pdo->prepare('SELECT url FROM place_images WHERE place_id = :pid ORDER BY COALESCE(sort_order,0) ASC');
$results = [];
foreach ($rows as $r) {
  $imgStmt->execute([':pid' => $r['id']]);
  $imgs = array_map(fn($x)=>$x['url'], $imgStmt->fetchAll());
  $results[] = place_row_to_json($r, $imgs);
}

json_out(['results' => $results]);
