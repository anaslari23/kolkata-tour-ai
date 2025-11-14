<?php
// One-time JSON -> MySQL ingestion
// Usage: http://localhost/api/admin_ingest_json.php  (place this file under htdocs/api)
require __DIR__ . '/lib.php';
$pdo = db_conn();

// Adjust path if needed: expects repo layout .../backend/data/kolkata_places.json
$repoRoot = dirname(__DIR__);
$jsonPath = $repoRoot . '/backend/data/kolkata_places.json';
if (!file_exists($jsonPath)) {
  json_out(['ok' => false, 'error' => 'JSON not found at '.$jsonPath], 400);
}
$raw = file_get_contents($jsonPath);
$items = json_decode($raw, true);
if (!is_array($items)) json_out(['ok'=>false,'error'=>'Invalid JSON'],400);

$pdo->beginTransaction();
try {
  $placeStmt = $pdo->prepare('INSERT INTO places (id,name,category,subcategory,description,history,nearby_recommendations,personal_tips,lat,lng,opening_hours,price,best_time,past_events,sentiment_tags,source_url,image)
    VALUES (:id,:name,:category,:subcategory,:description,:history,:nearby_recommendations,:personal_tips,:lat,:lng,:opening_hours,:price,:best_time,:past_events,:sentiment_tags,:source_url,:image)
    ON DUPLICATE KEY UPDATE name=VALUES(name), category=VALUES(category), subcategory=VALUES(subcategory), description=VALUES(description), history=VALUES(history), nearby_recommendations=VALUES(nearby_recommendations), personal_tips=VALUES(personal_tips), lat=VALUES(lat), lng=VALUES(lng), opening_hours=VALUES(opening_hours), price=VALUES(price), best_time=VALUES(best_time), past_events=VALUES(past_events), sentiment_tags=VALUES(sentiment_tags), source_url=VALUES(source_url), image=VALUES(image)');
  $imgDelStmt = $pdo->prepare('DELETE FROM place_images WHERE place_id = :pid');
  $imgInsStmt = $pdo->prepare('INSERT INTO place_images (place_id,url,sort_order) VALUES (:pid,:url,:ord)');

  $n=0;
  foreach ($items as $it) {
    $id = isset($it['id']) && $it['id'] !== '' ? (string)$it['id'] : '';
    if ($id === '') {
      $seed = preg_replace('/\s+/', '', strtolower((string)($it['name'] ?? 'unknown')));
      $id = '21' . substr($seed, 0, 20);
    }
    if (strpos($id, '21') !== 0) $id = '21'.$id;

    $name = (string)($it['name'] ?? ($it['Name'] ?? ''));
    $category = (string)($it['category'] ?? ($it['Category'] ?? ($it['Category & Subcategory'] ?? 'place')));
    $subcategory = isset($it['subcategory']) ? (string)$it['subcategory'] : null;
    $description = (string)($it['description'] ?? ($it['Description'] ?? ''));
    $history = (string)($it['history'] ?? ($it['History'] ?? ''));
    $nearby = $it['nearby_recommendations'] ?? [];
    $personal = (string)($it['personal_tips'] ?? '');
    $lat = isset($it['lat']) ? (float)$it['lat'] : (isset($it['Latitude']) ? (float)$it['Latitude'] : 0.0);
    $lng = isset($it['lng']) ? (float)$it['lng'] : (isset($it['Longitude']) ? (float)$it['Longitude'] : 0.0);
    $opening = $it['opening_hours'] ?? ($it['Opening Hours'] ?? null);
    $price = isset($it['price']) ? (string)$it['price'] : (isset($it['Price']) ? (string)$it['Price'] : null);
    $best_time = isset($it['best_time']) ? (string)$it['best_time'] : (isset($it['Best Time']) ? (string)$it['Best Time'] : null);
    $past = isset($it['past_events']) ? (string)$it['past_events'] : null;
    $tags = $it['tags'] ?? ($it['Sentiment Tags'] ?? []);
    if (is_string($tags)) {
      $tags = array_values(array_filter(array_map('trim', explode(',', $tags))));
    }

    $images = $it['images'] ?? ($it['Image URLs'] ?? []);
    if (is_string($images)) {
      $images = array_values(array_filter(array_map('trim', explode(',', $images))));
    }
    if (!is_array($images)) $images = [];
    $image = count($images) > 0 ? $images[0] : null;

    $placeStmt->execute([
      ':id' => $id,
      ':name' => $name,
      ':category' => $category,
      ':subcategory' => $subcategory,
      ':description' => $description,
      ':history' => $history,
      ':nearby_recommendations' => json_encode($nearby, JSON_UNESCAPED_UNICODE),
      ':personal_tips' => $personal,
      ':lat' => $lat,
      ':lng' => $lng,
      ':opening_hours' => $opening ? json_encode($opening, JSON_UNESCAPED_UNICODE) : null,
      ':price' => $price,
      ':best_time' => $best_time,
      ':past_events' => $past,
      ':sentiment_tags' => json_encode($tags, JSON_UNESCAPED_UNICODE),
      ':source_url' => isset($it['source_url']) ? (string)$it['source_url'] : null,
      ':image' => $image,
    ]);

    $imgDelStmt->execute([':pid' => $id]);
    $ord = 0;
    foreach ($images as $u) {
      if (!$u) continue;
      $imgInsStmt->execute([':pid'=>$id, ':url'=>$u, ':ord'=>$ord++]);
    }

    $n++;
  }
  $pdo->commit();
  json_out(['ok'=>true,'count'=>$n]);
} catch (Throwable $e) {
  $pdo->rollBack();
  json_out(['ok'=>false,'error'=>$e->getMessage()], 500);
}
