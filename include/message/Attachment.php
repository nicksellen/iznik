<?php

require_once(IZNIK_BASE . '/include/utils.php');
require_once(IZNIK_BASE . '/include/misc/Log.php');
require_once(IZNIK_BASE . '/include/message/Item.php');
require_once(IZNIK_BASE . '/include/misc/Image.php');

use Jenssegers\ImageHash\ImageHash;
use WindowsAzure\Common\ServicesBuilder;
use MicrosoftAzure\Storage\Blob\Models\CreateBlobOptions;

# This is a base class
class Attachment
{
    /** @var  $dbhr LoggedPDO */
    private $dbhr;
    /** @var  $dbhm LoggedPDO */
    private $dbhm;
    private $id, $table, $contentType, $hash, $archived;

    /**
     * @return null
     */
    public function getId()
    {
        return $this->id;
    }

    
    const TYPE_MESSAGE = 'Message';
    const TYPE_GROUP = 'Group';
    const TYPE_NEWSLETTER = 'Newsletter';
    const TYPE_COMMUNITY_EVENT = 'CommunityEvent';
    const TYPE_CHAT_MESSAGE = 'ChatMessage';
    const TYPE_USER = 'User';

    /**
     * @return mixed
     */
    public function getHash()
    {
        return $this->hash;
    }

    /**
     * @return mixed
     */
    public function getContentType()
    {
        return $this->contentType;
    }

    public function getPath($thumb = FALSE) {
        # We serve up our attachment names as though they are files.
        # When these are fetched it will go through image.php
        switch ($this->type) {
            case Attachment::TYPE_MESSAGE: $name = 'img'; break;
            case Attachment::TYPE_GROUP: $name = 'gimg'; break;
            case Attachment::TYPE_NEWSLETTER: $name = 'nimg'; break;
            case Attachment::TYPE_COMMUNITY_EVENT: $name = 'cimg'; break;
            case Attachment::TYPE_CHAT_MESSAGE: $name = 'mimg'; break;
            case Attachment::TYPE_USER: $name = 'uimg'; break;
        }

        $name = $thumb ? "t$name" : $name;
        $domain = $this->archived ? IMAGE_ARCHIVED_DOMAIN : IMAGE_DOMAIN;

        return("https://$domain/{$name}_{$this->id}.jpg");
    }

    public function getPublic() {
        $ret = array(
            'id' => $this->id,
            'hash' => $this->hash
        );

        if (stripos($this->contentType, 'image') !== FALSE) {
            # It's an image.  That's the only type we support.
            $ret['path'] = $this->getPath(FALSE);
            $ret['paththumb'] = $this->getPath(TRUE);
        }

        return($ret);
    }

    function __construct(LoggedPDO $dbhr, LoggedPDO $dbhm, $id = NULL, $type = Attachment::TYPE_MESSAGE)
    {
        $this->dbhr = $dbhr;
        $this->dbhm = $dbhm;
        $this->id = $id;
        $this->type = $type;
        $this->archived = FALSE;
        
        switch ($type) {
            case Attachment::TYPE_MESSAGE: $this->table = 'messages_attachments'; $this->idatt = 'msgid'; break;
            case Attachment::TYPE_GROUP: $this->table = 'groups_images'; $this->idatt = 'groupid'; break;
            case Attachment::TYPE_NEWSLETTER: $this->table = 'newsletters_images'; $this->idatt = 'articleid'; break;
            case Attachment::TYPE_COMMUNITY_EVENT: $this->table = 'communityevents_images'; $this->idatt = 'eventid'; break;
            case Attachment::TYPE_CHAT_MESSAGE: $this->table = 'chat_images'; $this->idatt = 'chatmsgid'; break;
            case Attachment::TYPE_USER: $this->table = 'users_images'; $this->idatt = 'userid'; break;
        }

        if ($id) {
            $sql = "SELECT contenttype, hash, archived FROM {$this->table} WHERE id = ?;";
            $atts = $this->dbhr->preQuery($sql, [$id]);
            foreach ($atts as $att) {
                $this->contentType = $att['contenttype'];
                $this->hash = $att['hash'];
                $this->archived = $att['archived'];
            }
        }
    }

    public function create($id, $ct, $data) {
        # We generate a perceptual hash.  This allows us to spot duplicate or similar images later.
        $hasher = new ImageHash;
        $img = @imagecreatefromstring($data);
        $hash = $img ? $hasher->hash($img) : NULL;

        $rc = $this->dbhm->preExec("INSERT INTO {$this->table} (`{$this->idatt}`, `contenttype`, `data`, `hash`) VALUES (?, ?, ?, ?);", [
            $id,
            $ct,
            $data,
            $hash
        ]);

        $imgid = $rc ? $this->dbhm->lastInsertId() : NULL;

        if ($imgid) {
            $this->id = $imgid;
            $this->contentType = $ct;
        }

        return($imgid);
    }

    public function getById($id) {
        $sql = "SELECT id FROM {$this->table} WHERE {$this->idatt} = ? AND ((data IS NOT NULL AND LENGTH(data) > 0) OR archived = 1) ORDER BY id;";
        $atts = $this->dbhr->preQuery($sql, [$id]);
        $ret = [];
        foreach ($atts as $att) {
            $ret[] = new Attachment($this->dbhr, $this->dbhm, $att['id']);
        }

        return($ret);
    }

    public function archive() {
        # We archive out of the DB into Azure.  This reduces load on the servers because we don't have to serve
        # the images up, and it also reduces the disk space we need within the DB (which is not an ideal
        # place to store large amounts of image data);
        #
        # If we fail then we leave it unchanged for next time.
        $data = $this->getData();
        $rc = TRUE;

        if ($data) {
            $rc = FALSE;

            try {
                $blobRestProxy = ServicesBuilder::getInstance()->createBlobService(AZURE_CONNECTION_STRING);
                $options = new CreateBlobOptions();
                $options->setBlobContentType("image/jpeg");

                $name = NULL;

                # Only these types are in archive_attachments.
                switch ($this->type) {
                    case Attachment::TYPE_MESSAGE: $tname = 'timg'; $name = 'img'; break;
                    case Attachment::TYPE_CHAT_MESSAGE: $tname = 'tmimg'; $name = 'mimg'; break;
                }

                if ($name) {
                    # Upload the thumbnail.  If this fails we'll leave it untouched.
                    $i = new Image($data);
                    if ($i->img) {
                        $i->scale(250, 250);
                        $thumbdata = $i->getData(100);
                        $blobRestProxy->createBlockBlob("images", "{$tname}_{$this->id}.jpg", $thumbdata, $options);

                        # Upload the full size image.
                        $blobRestProxy->createBlockBlob("images", "{$name}_{$this->id}.jpg", $data, $options);

                        $rc = TRUE;
                    } else {
                        error_log("...failed to create image");
                    }
                }

            } catch (Exception $e) { error_log("Archive failed " . $e->getMessage()); }
        }

        if ($rc) {
            # Remove from the DB.
            $sql = "UPDATE {$this->table} SET archived = 1, data = NULL WHERE id = {$this->id};";
            $this->dbhm->exec($sql);
        }

        return($rc);
    }

    public function setData($data) {
        $this->dbhm->preExec("UPDATE messages_attachments SET archived = 0, data = ? WHERE id = ?;", [
            $data,
            $this->id
        ]);
    }

    public function getData() {
        $ret = NULL;

        # Use dbhm to bypass query cache as this data is too large to cache.
        $sql = "SELECT * FROM {$this->table} WHERE id = ?;";
        $datas = $this->dbhm->preQuery($sql, [$this->id]);
        foreach ($datas as $data) {
            if ($data['archived']) {
                # This attachment has been archived out of our database, to a CDN.  Normally we would expect
                # that we wouldn't come through here, because we'd serve up an image link directly to the CDN, but
                # there is a timing window where we could archive after we've served up a link, so we have
                # to handle it.
                #
                # We fetch the data - not using SSL as we don't need to, and that host might not have a cert.  And
                # we put it back in the DB, because we are probably going to fetch it again.
                # Only these types are in archive_attachments.
                switch ($this->type) {
                    case Attachment::TYPE_MESSAGE: $tname = 'timg'; $name = 'img'; break;
                    case Attachment::TYPE_CHAT_MESSAGE: $tname = 'tmimg'; $name = 'mimg'; break;
                }

                $url = 'https://' . IMAGE_ARCHIVED_DOMAIN . "/{$name}_{$this->id}.jpg";
                $ret = @file_get_contents($url);
            } else {
                $ret = $data['data'];
            }
        }

        return($ret);
    }

    public function identify() {
        # Identify objects in an attachment using Google Vision API.  Only for messages.
        $items = [];
        if ($this->type == Attachment::TYPE_MESSAGE) {
            $data = $this->getData();
            $base64 = base64_encode($data);

            $r_json ='{
			  	"requests": [
					{
					  "image": {
					    "content":"' . $base64. '"
					  },
					  "features": [
					      {
					      	"type": "LABEL_DETECTION",
							"maxResults": 20
					      }
					  ]
					}
				]
			}';

            $curl = curl_init();
            curl_setopt($curl, CURLOPT_URL, 'https://vision.googleapis.com/v1/images:annotate?key=' . GOOGLE_VISION_KEY);
            curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($curl, CURLOPT_HTTPHEADER, array("Content-type: application/json"));
            curl_setopt($curl, CURLOPT_POST, true);
            curl_setopt($curl, CURLOPT_POSTFIELDS, $r_json);
            $json_response = curl_exec($curl);
            $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);

            if ($status) {
                $this->dbhm->preExec("UPDATE messages_attachments SET identification = ? WHERE id = ?;", [ $json_response, $this->id ]);
                $rsp = json_decode($json_response, TRUE);
                #error_log("Identified {$this->id} by Google $json_response for $r_json");

                if (array_key_exists('responses', $rsp) && count($rsp['responses']) > 0 && array_key_exists('labelAnnotations', $rsp['responses'][0])) {
                    $rsps = $rsp['responses'][0]['labelAnnotations'];
                    $i = new Item($this->dbhr, $this->dbhm);

                    foreach ($rsps as $rsp) {
                        $found = $i->findFromPhoto($rsp['description']);
                        $wasfound = FALSE;
                        foreach ($found as $item) {
                            $this->dbhm->background("INSERT INTO messages_attachments_items (attid, itemid) VALUES ({$this->id}, {$item['id']});");
                            $wasfound = TRUE;
                        }

                        if (!$wasfound) {
                            # Record items which were suggested but not considered as items by us.  This allows us to find common items which we ought to
                            # add.
                            #
                            # This is usually because they're too vague.
                            $url = "https://" . IMAGE_DOMAIN . "/img_{$this->id}.jpg";
                            $this->dbhm->background("INSERT INTO items_non (name, lastexample) VALUES (" . $this->dbhm->quote($rsp['description']) . ", " . $this->dbhm->quote($url) . ") ON DUPLICATE KEY UPDATE popularity = popularity + 1, lastexample = " . $this->dbhm->quote($url) . ";");
                        }

                        $items = array_merge($items, $found);
                    }
                }
            }

            curl_close($curl);
        }

        return($items);
    }

    public function ocr() {
        # Identify text in an attachment using Google Vision API.
        $data = $this->getData();
        $base64 = base64_encode($data);

        $r_json ='{
            "requests": [
                {
                  "image": {
                    "content":"' . $base64. '"
                  },
                  "features": [
                      {
                        "type": "TEXT_DETECTION"
                      }
                  ]
                }
            ]
        }';

        $curl = curl_init();
        curl_setopt($curl, CURLOPT_URL, 'https://vision.googleapis.com/v1/images:annotate?key=' . GOOGLE_VISION_KEY);
        curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curl, CURLOPT_HTTPHEADER, array("Content-type: application/json"));
        curl_setopt($curl, CURLOPT_POST, true);
        curl_setopt($curl, CURLOPT_POSTFIELDS, $r_json);
        $json_response = curl_exec($curl);
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);

        $text = '';

        if ($status) {
            $rsp = json_decode($json_response, TRUE);
            #error_log("Decoded " . var_export($rsp, TRUE));

            if (array_key_exists('responses', $rsp) && count($rsp['responses']) > 0 && array_key_exists('textAnnotations', $rsp['responses'][0])) {
                $rsps = $rsp['responses'][0]['textAnnotations'];

                foreach ($rsps as $rsp) {
                    #error_log($rsp['description']);
                    $text .= $rsp['description'] . "\n";
                }
            }
        }

        curl_close($curl);

        return($text);
    }

    public function setPrivate($att, $val) {
        $rc = $this->dbhm->preExec("UPDATE {$this->table} SET `$att` = ? WHERE id = {$this->id};", [$val]);
    }
}