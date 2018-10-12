<?php

$date = new DateTime('2018-10-12'); echo $date->format("Y-m-d")." => ".$date->getTimestamp()."\n";
$date = new DateTime('2018-10-31'); echo $date->format("Y-m-d")." => ".$date->getTimestamp()."\n";
$date = new DateTime('2018-11-26'); echo $date->format("Y-m-d")." => ".$date->getTimestamp()."\n";
$date = new DateTime('2019-02-26'); echo $date->format("Y-m-d")." => ".$date->getTimestamp()."\n";

?>
