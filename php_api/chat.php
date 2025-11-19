<?php
require_once __DIR__ . '/lib.php';

// 1. Get Input
$input = json_decode(file_get_contents('php://input'), true) ?? [];
$msg = trim($input['message'] ?? '');
$city = $input['city'] ?? 'Kolkata';
$userId = $input['user_id'] ?? 'anon';
$hour = $input['hour'] ?? (int)date('H');

if (!$msg) {
  json_out(['answer' => "Hi! I'm your Kolkata guide. Ask me anything about places, food, or history.", 'context' => []]);
}

// 2. Search Context (Improved Keyword Search)
$pdo = db_conn();
$keywords = array_filter(explode(' ', preg_replace('/[^a-zA-Z0-9 ]/', '', strtolower($msg))), function($w){ return strlen($w) > 2; }); // Changed from 3 to 2

$contextItems = [];
if (!empty($keywords)) {
  // Build dynamic query with better matching
  $likes = [];
  $params = [];
  foreach ($keywords as $k) {
    $likes[] = "(LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(history) LIKE ? OR LOWER(personal_tips) LIKE ? OR LOWER(category) LIKE ?)";
    $params[] = "%$k%";
    $params[] = "%$k%";
    $params[] = "%$k%";
    $params[] = "%$k%";
    $params[] = "%$k%";
  }
  $sql = "SELECT * FROM places WHERE " . implode(' OR ', $likes) . " LIMIT 8";
  
  try {
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    foreach ($rows as $r) {
      $contextItems[] = place_row_to_json($r, []); // simplified, no extra image query
    }
  } catch (Exception $e) {
    // ignore search errors
  }
}

// Fallback: if no context found, return some popular/random places
if (empty($contextItems)) {
    try {
        $stmt = $pdo->query("SELECT * FROM places ORDER BY RAND() LIMIT 5");
        $rows = $stmt->fetchAll();
        foreach ($rows as $r) {
            $contextItems[] = place_row_to_json($r, []);
        }
    } catch (Exception $e) {
        // ignore
    }
}

// 3. Format Context for LLM
$contextText = "";
foreach ($contextItems as $it) {
  $name = $it['name'];
  $cat = $it['category'];
  $desc = substr($it['description'], 0, 150);
  $hist = substr($it['history'], 0, 100);
  $tips = substr($it['personal_tips'], 0, 100);
  $hours = is_array($it['opening_hours']) ? implode(', ', $it['opening_hours']) : $it['opening_hours'];
  $price = $it['price'];
  
  $contextText .= "- $name ($cat): $desc. History: $hist. Tips: $tips. Hours: $hours. Price: $price.\n";
}

// 4. Call Ollama
$ollamaUrl = 'http://127.0.0.1:11434/api/generate';
$model = getenv('OLLAMA_MODEL') ?: 'mistral'; // Use mistral for better responses

$systemPrompt = "You are a knowledgeable Kolkata local guide. Reply in 2-3 sentences. Use the provided context to answer questions about places, timings, prices, and tips. Be helpful and friendly.";

$prompt = "System: $systemPrompt\nUser: $msg\nContext:\n$contextText\nAssistant:";

$payload = json_encode([
  'model' => $model,
  'prompt' => $prompt,
  'stream' => false
]);

$opts = [
  'http' => [
    'method' => 'POST',
    'header' => "Content-Type: application/json\r\n",
    'content' => $payload,
    'timeout' => 30, // Increased timeout for Ollama
    'ignore_errors' => true // Don't throw on HTTP errors
  ]
];

$answer = "";
$ollamaError = "";
try {
  $context = stream_context_create($opts);
  $res = @file_get_contents($ollamaUrl, false, $context);
  
  if ($res !== false) {
    $data = json_decode($res, true);
    if ($data && isset($data['response'])) {
      $answer = trim($data['response']);
    } else {
      $ollamaError = "Invalid Ollama response format";
    }
  } else {
    $ollamaError = "Failed to connect to Ollama";
  }
} catch (Exception $e) {
  $ollamaError = $e->getMessage();
}

// Fallback answer if Ollama fails
if (!$answer) {
  if (!empty($contextItems)) {
    $top = $contextItems[0];
    $name = $top['name'];
    $desc = $top['description'];
    $tips = $top['personal_tips'];
    $hours = is_array($top['opening_hours']) ? implode(', ', $top['opening_hours']) : $top['opening_hours'];
    $price = $top['price'];
    
    // Build a smarter fallback response
    $answer = "You might like $name. $desc";
    if ($tips) {
      $answer .= " Tip: $tips";
    }
    if ($hours) {
      $answer .= " Open: $hours.";
    }
    if ($price) {
      $answer .= " Price: $price.";
    }
  } else {
    $answer = "I'm having trouble finding relevant places. Try asking about specific locations like Victoria Memorial, Howrah Bridge, or Park Street!";
  }
}

// 5. Return Response
json_out([
  'answer' => $answer,
  'context' => $contextItems
]);
