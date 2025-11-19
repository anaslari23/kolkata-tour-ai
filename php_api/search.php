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
  $where[] = '(name LIKE :q_any OR description LIKE :q_any OR category LIKE :q_any OR subcategory LIKE :q_any OR sentiment_tags LIKE :q_json OR sentiment_tags LIKE :q_csv)';
  $args[':q_any'] = "%$q%";
  $args[':q_json'] = "%\"$q\"%"; // match JSON string value in array
  $args[':q_csv'] = "%$q%";         // match CSV/plain text
}
if ($category) {
  $where[] = '(category LIKE :cat OR subcategory LIKE :cat OR sentiment_tags LIKE :cat_json OR sentiment_tags LIKE :cat_csv)';
  $args[':cat'] = "%$category%";
  $args[':cat_json'] = "%\"$category\"%";
  $args[':cat_csv'] = "%$category%";
}
$whereSql = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

$sql = "SELECT p.*, 
  (
    (CASE WHEN p.name = :q_exact THEN 100 ELSE 0 END) +
    (CASE WHEN p.name LIKE :q_prefix THEN 60 ELSE 0 END) +
    (CASE WHEN p.name LIKE :q_any2 THEN 40 ELSE 0 END) +
    (CASE WHEN (p.category LIKE :q_any2 OR p.subcategory LIKE :q_any2) THEN 25 ELSE 0 END) +
    (CASE WHEN p.sentiment_tags LIKE :q_json2 OR p.sentiment_tags LIKE :q_csv2 THEN 30 ELSE 0 END) +
    (CASE WHEN p.description LIKE :q_any2 THEN 20 ELSE 0 END)
  ) AS score
FROM places p
$whereSql
ORDER BY score DESC, p.name ASC
LIMIT :lim";
$stmt = $pdo->prepare($sql);
foreach ($args as $k2=>$v) { $stmt->bindValue($k2, $v); }
// scoring params (safe even if q is empty; values won't be used when q is empty)
$stmt->bindValue(':q_exact', $q);
$stmt->bindValue(':q_prefix', $q !== '' ? ($q.'%') : '');
$stmt->bindValue(':q_any2', "%$q%");
$stmt->bindValue(':q_json2', "%\"$q\"%");
$stmt->bindValue(':q_csv2', "%$q%");
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
