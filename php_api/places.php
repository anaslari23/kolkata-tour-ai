<?php
require __DIR__ . '/lib.php';
$pdo = db_conn();

$category = isset($_GET['type']) ? trim($_GET['type']) : (isset($_GET['category']) ? trim($_GET['category']) : null);
$subcategory = isset($_GET['subcategory']) ? trim($_GET['subcategory']) : null;
$page = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
$pageSize = isset($_GET['page_size']) ? max(1, min(100, (int)$_GET['page_size'])) : 20;
$offset = ($page - 1) * $pageSize;

$where = [];
$args = [];
if ($category) {
  $where[] = '(category LIKE :cat OR subcategory LIKE :cat OR sentiment_tags LIKE :cat_json OR sentiment_tags LIKE :cat_csv)';
  $args[':cat'] = "%$category%";
  $args[':cat_json'] = "%\"$category\"%"; // matches JSON string value
  $args[':cat_csv'] = "%$category%"; // matches CSV plain text
}
if ($subcategory) {
  $where[] = 'subcategory LIKE :sub';
  $args[':sub'] = "%$subcategory%";
}
$whereSql = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

// total
$stmt = $pdo->prepare("SELECT COUNT(*) AS c FROM places $whereSql");
$stmt->execute($args);
$total = (int)$stmt->fetch()['c'];

// items
$sql = "SELECT * FROM places $whereSql ORDER BY name ASC LIMIT :limit OFFSET :offset";
$stmt = $pdo->prepare($sql);
foreach ($args as $k=>$v) { $stmt->bindValue($k, $v); }
$stmt->bindValue(':limit', $pageSize, PDO::PARAM_INT);
$stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
$stmt->execute();
$rows = $stmt->fetchAll();

// images per place
$results = [];
$imgStmt = $pdo->prepare('SELECT url FROM place_images WHERE place_id = :pid ORDER BY COALESCE(sort_order,0) ASC');
foreach ($rows as $r) {
  $imgStmt->execute([':pid' => $r['id']]);
  $imgs = array_map(fn($x)=>$x['url'], $imgStmt->fetchAll());
  $results[] = place_row_to_json($r, $imgs);
}

json_out(['results' => $results, 'page' => $page, 'page_size' => $pageSize, 'total' => $total]);
