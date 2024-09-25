<?PHP
error_reporting (E_ALL ^ E_NOTICE);
// Version=1.6
  $hostdir = $_POST['hostdir'];
  $version = $_POST['version'];
  if(!empty($_FILES['uploaded_file']))
  {
   echo  PHP_EOL . "Enroll To The Jungle - version: " . $version . PHP_EOL ;
   $manifets_path = '../manifests/' . $hostdir . '/' ;
    $path = $manifets_path . basename( $_FILES['uploaded_file']['name']);
    if(move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $path)) {
      echo "The manifest ".  basename( $_FILES['uploaded_file']['name']).
      " has been uploaded in munki repo: " . PHP_EOL  . 'manifests/' . $hostdir . " directory" . PHP_EOL ;
    } else {
        echo "There was an error uploading the manifest, please try again!"  . PHP_EOL ;
    }
  }
?>
