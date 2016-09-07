<?php

require_once(IZNIK_BASE . '/include/utils.php');

class Events {
    private $dbhr;
    private $dbhm;

    private $queue = '';

    function __construct(LoggedPDO $dbhr, LoggedPDO $dbhm) {
        $this->dbhr = $dbhr;
        $this->dbhm = $dbhm;
    }

    public function record($id, $sessid, $route, $target, $action, $timestamp, $posx, $posy, $viewx, $viewy, $data) {
        # TODO POST protection will stop blatant hacks but URLs with timestamps would get through.
        $timestamp = $timestamp ? ($timestamp * 0.001) : 'NULL';
        $posx = $posx ? $posx : 'NULL';
        $posy = $posy ? $posy : 'NULL';
        $hashvalue = $data ? md5($data) : NULL;
        $datahash = $data ? ("'" . $hashvalue . "'") : 'NULL';
        $dataq = $data ? $this->dbhr->quote($data) : 'NULL';
        $datasameas = 'NULL';
        $id = $id ? $id : 'NULL';

        if ($data) {
            # To save space in the table, we look for another record which has the same hash, and then data.  If we find
            # one, then can flag this entry as having the same data as that one.  This helps a lot, because we only have
            # a finite set of pages, and some of them are static, so our periodic DOM-f events would otherwise generate
            # a lot of data.
            $sql = "SELECT * FROM logs_events WHERE datahash = ? AND datasameas IS NULL LIMIT 10;";
            $start= microtime(TRUE);
            $logs = $this->dbhr->preQuery($sql, [ $hashvalue ]);
            foreach ($logs as $log) {
                $cmp = strcmp($log['data'], $data);
                if ($cmp == 0) {
                    $dataq = 'NULL';
                    $datasameas = $log['id'];
                    break;
                }
            }
        }

        $lastip = presdef('REMOTE_ADDR', $_SERVER, 'NULL');

        $sql = "INSERT IGNORE INTO logs_events (`userid`, `sessionid`, `timestamp`, `clienttimestamp`, `route`, `target`, `event`, `posx`, `posy`, `viewx`, `viewy`, `data`, `datahash`, `datasameas`, `ip`) VALUES ($id, " . $this->dbhr->quote($sessid) . ", CURTIME(3), FROM_UNIXTIME($timestamp), " . $this->dbhr->quote($route) . ", " . $this->dbhr->quote($target) . ", " . $this->dbhr->quote($action) . ", $posx, $posy, $viewx, $viewy, $dataq, $datahash, $datasameas, " . $this->dbhr->quote($lastip) . ");";

        $this->queue .= $sql;
    }

    public function flush() {
        try {
            # If anything goes wrong, we're not that interested - we can lose events, and if we return errors the
            # client will retry.
            $this->dbhm->background($this->queue);
            $this->queue = '';
        } catch (Exception $e) {}
    }
    
    public function listSessions($userid = NULL) {
        $userq = $userid ? " WHERE userid = $userid " : '';
        $sql = "SELECT DISTINCT(sessionid) FROM logs_events $userq ORDER BY id DESC LIMIT 100;";
        $sessions = $this->dbhr->preQuery($sql);
        $ret = [];
        
        foreach ($sessions as $session) {
            $sessid = $session['sessionid'];
            $thisone = [
                'id' => $sessid
            ];

            $sql = "SELECT MAX(viewx) AS viewx, MAX(viewy) AS viewy, MAX(route) AS route, MAX(ip) AS ip, MAX(userid) AS userid, MIN(timestamp) AS start, MAX(timestamp) AS end, sessionid FROM logs_events WHERE sessionid = ?;";
            $sessions = $this->dbhr->preQuery($sql, [ $sessid ]);
            foreach ($sessions as $session) {
                $thisone['ip'] = $session['ip'];

                if ($thisone['ip']) {
                    $thisone['modtools'] = strpos($session['route'], 'modtools') !== FALSE;
                    $thisone['viewx'] = $session['viewx'];
                    $thisone['viewy'] = $session['viewy'];

                    if ($session['userid']) {
                        $u = new User($this->dbhr, $this->dbhm, $session['userid']);
                        $thisone['user'] = $u->getPublic(NULL, FALSE);
                    }

                    $thisone['start'] = ISODate($session['start']);
                    $thisone['end'] = ISODate($session['end']);

                    $ret[] = $thisone;
                }
            }
        }
        
        return($ret);
    }

    public function get($sessionid) {
        $events = NULL;

        # Get the first client timestamp.
        $sql = "SELECT clienttimestamp FROM logs_events WHERE sessionid = ? ORDER BY id ASC LIMIT 1;";
        error_log("$sql, $sessionid");
        $firsts = $this->dbhr->preQuery($sql, [
            $sessionid
        ]);

        foreach ($firsts as $first) {
            $sql = "SELECT *, TIMESTAMPDIFF(MICROSECOND, ?, clienttimestamp) / 1000 AS clientdiff FROM logs_events WHERE sessionid = ? ORDER BY clienttimestamp ASC;";
            $events = $this->dbhr->preQuery($sql, [
                $first['clienttimestamp'],
                $sessionid
            ]);

            $last = null;

            # Convert the differences into relative diffs between the items.
            foreach ($events as &$item) {
                $thisone = $item['clientdiff'];

                if ($item['datasameas']) {
                    # The other one might have gone, but if so we'll just not find it.
                    $sql = "SELECT data FROM logs_events WHERE id = ?;";
                    $logs = $this->dbhr->preQuery($sql, [ $item['datasameas'] ]);
                    foreach ($logs as $log) {
                        $item['data'] = $log['data'];
                    }
                }

                if ($last) {
                    $item['clientdiff'] = floatval($item['clientdiff']) - $last;
                } else {
                    $item['clientdiff'] = floatval(0);
                }

                $last = $thisone;
            }
        }

        return($events);
    }
}