<?php
function db_conn() {
  $cfg = require __DIR__ . '/config.php';
  $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s', $cfg['host'], $cfg['port'], $cfg['db'], $cfg['charset']);
  $pdo = new PDO($dsn, $cfg['user'], $cfg['pass'], [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
  return $pdo;
}

function json_out($data, $status=200){
  http_response_code($status);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($data, JSON_UNESCAPED_UNICODE);
  exit;
}

function place_row_to_json($p, $images){
  // Normalize coordinates (support alternate column names)
  $latRaw = $p['lat'] ?? ($p['latitude'] ?? null);
  $lngRaw = $p['lng'] ?? ($p['longitude'] ?? null);
  $lat = $latRaw !== null ? (float)$latRaw : 0.0;
  $lng = $lngRaw !== null ? (float)$lngRaw : 0.0;

  // opening_hours: JSON or plain string
  $openingRaw = $p['opening_hours'] ?? null;
  $opening = null;
  if (is_string($openingRaw) && strlen(trim($openingRaw)) > 0) {
    $tmp = json_decode($openingRaw, true);
    if (json_last_error() === JSON_ERROR_NONE && (is_array($tmp) || is_object($tmp))) {
      $opening = $tmp;
    } else {
      $opening = $openingRaw;
    }
  } elseif (is_array($openingRaw) || is_object($openingRaw)) {
    $opening = $openingRaw;
  }

  // nearby_recommendations: JSON or plain string -> object with 'recommendations'
  $nearbyRaw = $p['nearby_recommendations'] ?? null;
  $nearby = [];
  if (is_string($nearbyRaw) && strlen(trim($nearbyRaw)) > 0) {
    $tmp = json_decode($nearbyRaw, true);
    if (json_last_error() === JSON_ERROR_NONE && (is_array($tmp) || is_object($tmp))) {
      $nearby = $tmp;
    } else {
      $nearby = ['recommendations' => $nearbyRaw];
    }
  } elseif (is_array($nearbyRaw) || is_object($nearbyRaw)) {
    $nearby = $nearbyRaw;
  }

  // tags: JSON array text or comma-separated string
  $tagsRaw = $p['sentiment_tags'] ?? null;
  $tags = [];
  if (is_string($tagsRaw) && strlen(trim($tagsRaw)) > 0) {
    $tmp = json_decode($tagsRaw, true);
    if (json_last_error() === JSON_ERROR_NONE && is_array($tmp)) {
      $tags = $tmp;
    } else {
      $tags = array_values(array_filter(array_map(function($t){ return trim($t); }, explode(',', $tagsRaw)), function($t){ return $t !== ''; }));
    }
  } elseif (is_array($tagsRaw)) {
    $tags = $tagsRaw;
  }

  // images: prefer place_images table; else fallback to image_urls column (comma-separated)
  $fallbackImages = [];
  if (empty($images)) {
    $imgUrls = $p['image_urls'] ?? '';
    if (is_string($imgUrls) && strlen(trim($imgUrls)) > 0) {
      $fallbackImages = array_values(array_filter(array_map(function($u){ return trim($u); }, explode(',', $imgUrls)), function($u){ return $u !== ''; }));
    }
  }
  $finalImages = !empty($images) ? $images : $fallbackImages;

  // primary image: explicit column or first of images
  $primaryImage = $p['image'] ?? '';
  if ((!is_string($primaryImage) || $primaryImage === '') && !empty($finalImages)) {
    $primaryImage = $finalImages[0];
  }

  return [
    'id' => $p['id'],
    'name' => $p['name'] ?? '',
    'category' => $p['category'] ?? '',
    'subcategory' => $p['subcategory'] ?? '',
    'description' => $p['description'] ?? '',
    'history' => $p['history'] ?? '',
    'nearby_recommendations' => $nearby,
    'personal_tips' => $p['personal_tips'] ?? '',
    'lat' => $lat,
    'lng' => $lng,
    'opening_hours' => $opening,
    'price' => $p['price'] ?? '',
    'best_time' => $p['best_time'] ?? '',
    'past_events' => $p['past_events'] ?? '',
    'tags' => $tags,
    'image' => $primaryImage,
    'images' => $finalImages,
    'source_url' => $p['source_url'] ?? '',
  ];
}

function haversine_km($lat1,$lon1,$lat2,$lon2){
  $R=6371.0;
  $dphi=deg2rad($lat2-$lat1);
  $dl=deg2rad($lon2-$lon1);
  $phi1=deg2rad($lat1);
  $phi2=deg2rad($lat2);
  $a=sin($dphi/2)**2 + cos($phi1)*cos($phi2)*sin($dl/2)**2;
  $c=2*atan2(sqrt($a), sqrt(1-$a));
  return $R*$c;
}
