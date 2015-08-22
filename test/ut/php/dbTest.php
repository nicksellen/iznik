<?php

require_once 'IznikTest.php';
require_once BASE_DIR . '/include/db.php';

/**
 * @backupGlobals disabled
 * @backupStaticAttributes disabled
 */
class dbTest extends IznikTest {
    /** @var $dbhr LoggedPDO */
    /** @var $dbhm LoggedPDO */
    private $dbhr, $dbhm;

    protected function setUp() {
        parent::setUp ();

        global $dbhr, $dbhm;
        $this->dbhr = $dbhr;
        $this->dbhm = $dbhm;

        assertNotNull($this->dbhr);
        assertNotNull($this->dbhm);

        $rc = $this->dbhm->exec('CREATE TABLE `test` (`id` int(11) NOT NULL AUTO_INCREMENT, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=latin1;');
        assertEquals(0, $rc);
    }

    protected function tearDown() {
        $rc = $this->dbhm->exec('DROP TABLE test;');
        assertEquals(0, $rc);

        parent::tearDown ();
    }

    public function __construct() {
    }

    public function testBasic() {
        error_log(__METHOD__);

        $tables = $this->dbhm->retryQuery('SHOW COLUMNS FROM test;')->fetchAll();
        assertEquals('id', $tables[0]['Field']);
        assertGreaterThan(0, $this->dbhm->getWaitTime());

        error_log(__METHOD__ . " end");
    }

    public function testInsert() {
        error_log(__METHOD__);

        $rc = $this->dbhm->exec('INSERT INTO test VALUES ();');
        assertEquals(1, $rc);
        $id1 = $this->dbhm->lastInsertId();
        $rc = $this->dbhm->exec('INSERT INTO test VALUES ();');
        assertEquals(1, $rc);
        $id2 = $this->dbhm->lastInsertId();
        assertGreaterThan($id1, $id2);

        error_log(__METHOD__ . " end");
    }

    public function testTransaction() {
        error_log(__METHOD__);

        $rc = $this->dbhm->beginTransaction();

        $rc = $this->dbhm->exec('INSERT INTO test VALUES ();');
        assertEquals(1, $rc);
        assertGreaterThan(0, $this->dbhm->lastInsertId());

        $tables = $this->dbhm->query('SHOW COLUMNS FROM test;')->fetchAll();
        assertEquals('id', $tables[0]['Field']);

        $rc = $this->dbhm->commit();
        assertTrue($rc);

        error_log(__METHOD__ . " end");
    }

    public function testBackground() {
        error_log(__METHOD__);

        # Test creation of the Pheanstalk.
        $this->dbhm->background('INSERT INTO test VALUES ();');

        # Mock the put to work.
        $mock = $this->getMockBuilder('Pheanstalk\Pheanstalk')
            ->disableOriginalConstructor()
            ->setMethods(array('put'))
            ->getMock();
        $mock->method('put')->willReturn(true);
        $this->dbhm->setPheanstalk($mock);
        $this->dbhm->background('INSERT INTO test VALUES ();');

        # Mock the put to fail.
        $mock->method('put')->will($this->throwException(new Exception()));
        $this->dbhm->background('INSERT INTO test VALUES ();');

        error_log(__METHOD__ . " end");
    }

    public function exceptionUntil() {
        error_log("exceptionUntil count " . $this->count);
        $this->count--;
        if ($this->count > 0) {
            error_log("Exception");
            throw new Exception('Faked deadlock exception');
        } else {
            error_log("No exception");
            return false;
        }
    }

    public function testQueryRetries() {
        error_log(__METHOD__);

        # We mock up the query to throw an exception, to test retries.
        #
        # First a non-deadlock exception
        $mock = $this->getMockBuilder('LoggedPDO')
            ->disableOriginalConstructor()
            ->setMethods(array('parentQuery'))
            ->getMock();
        $mock->method('parentQuery')->will($this->throwException(new Exception()));

        $worked = false;

        try {
            $mock->retryQuery('SHOW COLUMNS FROM test;');
        } catch (DBException $e) {
            $worked = true;
            assertContains('Non-deadlock', $e->getMessage());
        }
        assertTrue($worked);

        # Now a deadlock that never gets resolved
        $mock = $this->getMockBuilder('LoggedPDO')
            ->disableOriginalConstructor()
            ->setMethods(array('parentQuery'))
            ->getMock();
        $mock->method('parentQuery')->will($this->throwException(new Exception('Faked deadlock exception')));
        $worked = false;

        try {
            $mock->retryQuery('SHOW COLUMNS FROM test;');
        } catch (DBException $e) {
            $worked = true;
            assertEquals('Unexpected database error Faked deadlock exception', $e->getMessage());
        }
        assertTrue($worked);

        # Now a deadlock that gets resolved
        $mock = $this->getMockBuilder('LoggedPDO')
            ->disableOriginalConstructor()
            ->setMethods(array('parentQuery'))
            ->getMock();
        $this->count = 5;
        $mock->method('parentQuery')->will($this->returnCallback(function() {
            return($this->exceptionUntil());
        }));
        $worked = false;

        $mock->retryQuery('SHOW COLUMNS FROM test;');

        error_log(__METHOD__ . " end");
    }

    public function testExecRetries() {
        error_log(__METHOD__);

        # We mock up the query to throw an exception, to test retries.
        #
        # First a non-deadlock exception
        $mock = $this->getMockBuilder('LoggedPDO')
            ->disableOriginalConstructor()
            ->setMethods(array('parentExec'))
            ->getMock();
        $mock->method('parentExec')->will($this->throwException(new Exception()));

        $worked = false;

        try {
            $mock->retryExec('INSERT INTO test VALUES ();');
        } catch (DBException $e) {
            $worked = true;
            assertContains('Non-deadlock', $e->getMessage());
        }
        assertTrue($worked);

        # Now a deadlock that never gets resolved
        $mock = $this->getMockBuilder('LoggedPDO')
            ->disableOriginalConstructor()
            ->setMethods(array('parentExec'))
            ->getMock();
        $mock->method('parentExec')->will($this->throwException(new Exception('Faked deadlock exception')));
        $worked = false;

        try {
            $mock->retryExec('INSERT INTO test VALUES ();');
        } catch (DBException $e) {
            $worked = true;
            assertEquals('Unexpected database error Faked deadlock exception', $e->getMessage());
        }
        assertTrue($worked);

        # Now a deadlock that gets resolved
        $mock = $this->getMockBuilder('LoggedPDO')
            ->disableOriginalConstructor()
            ->setMethods(array('parentExec'))
            ->getMock();
        $this->count = 5;
        $mock->method('parentExec')->will($this->returnCallback(function() {
            return($this->exceptionUntil());
        }));
        $worked = false;

        $mock->retryExec('INSERT INTO test VALUES ();');

        error_log(__METHOD__ . " end");
    }
}

