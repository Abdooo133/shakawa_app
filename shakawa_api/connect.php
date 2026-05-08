<?php

//google cloud
$servername = "db";
$username = "root";
$password = "Abdo@2026";
$dbname = "shakawa_backend";

// //docker
// $servername = "db";
// $username = "root";
// $password = "password";
// $dbname = "shakawa_db"; 

//local
// $servername = "db";
// $username = "root";
// $password = "123456";
// $dbname = "shakawa_db"; 

 

$conn = new mysqli($servername, $username, $password, $dbname);

// 🛡️ التعديل: ضبط التوقيت ليكون بتوقيت القاهرة
date_default_timezone_set('Africa/Cairo');

// دعم كامل للغة العربية والإيموجي
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    die(json_encode([
        "status" => "error", 
        "message" => "فشل الاتصال: " . $conn->connect_error
    ]));
}


?>