-- phpMyAdmin SQL Dump
-- version 4.0.10deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Oct 04, 2017 at 02:17 PM
-- Server version: 5.7.17-13-57
-- PHP Version: 5.5.9-1ubuntu4.21

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

--
-- Database: `iznik`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`app2` PROCEDURE `ANALYZE_INVALID_FOREIGN_KEYS`(
  checked_database_name VARCHAR(64),
  checked_table_name VARCHAR(64),
  temporary_result_table ENUM('Y', 'N'))
READS SQL DATA
  BEGIN
    DECLARE TABLE_SCHEMA_VAR VARCHAR(64);
    DECLARE TABLE_NAME_VAR VARCHAR(64);
    DECLARE COLUMN_NAME_VAR VARCHAR(64);
    DECLARE CONSTRAINT_NAME_VAR VARCHAR(64);
    DECLARE REFERENCED_TABLE_SCHEMA_VAR VARCHAR(64);
    DECLARE REFERENCED_TABLE_NAME_VAR VARCHAR(64);
    DECLARE REFERENCED_COLUMN_NAME_VAR VARCHAR(64);
    DECLARE KEYS_SQL_VAR VARCHAR(1024);

    DECLARE done INT DEFAULT 0;

    DECLARE foreign_key_cursor CURSOR FOR
      SELECT
        `TABLE_SCHEMA`,
        `TABLE_NAME`,
        `COLUMN_NAME`,
        `CONSTRAINT_NAME`,
        `REFERENCED_TABLE_SCHEMA`,
        `REFERENCED_TABLE_NAME`,
        `REFERENCED_COLUMN_NAME`
      FROM
        information_schema.KEY_COLUMN_USAGE
      WHERE
        `CONSTRAINT_SCHEMA` LIKE checked_database_name AND
        `TABLE_NAME` LIKE checked_table_name AND
        `REFERENCED_TABLE_SCHEMA` IS NOT NULL;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    IF temporary_result_table = 'N' THEN
      DROP TEMPORARY TABLE IF EXISTS INVALID_FOREIGN_KEYS;
      DROP TABLE IF EXISTS INVALID_FOREIGN_KEYS;

      CREATE TABLE INVALID_FOREIGN_KEYS(
        `TABLE_SCHEMA` VARCHAR(64),
        `TABLE_NAME` VARCHAR(64),
        `COLUMN_NAME` VARCHAR(64),
        `CONSTRAINT_NAME` VARCHAR(64),
        `REFERENCED_TABLE_SCHEMA` VARCHAR(64),
        `REFERENCED_TABLE_NAME` VARCHAR(64),
        `REFERENCED_COLUMN_NAME` VARCHAR(64),
        `INVALID_KEY_COUNT` INT,
        `INVALID_KEY_SQL` VARCHAR(1024)
      );
    ELSEIF temporary_result_table = 'Y' THEN
      DROP TEMPORARY TABLE IF EXISTS INVALID_FOREIGN_KEYS;
      DROP TABLE IF EXISTS INVALID_FOREIGN_KEYS;

      CREATE TEMPORARY TABLE INVALID_FOREIGN_KEYS(
        `TABLE_SCHEMA` VARCHAR(64),
        `TABLE_NAME` VARCHAR(64),
        `COLUMN_NAME` VARCHAR(64),
        `CONSTRAINT_NAME` VARCHAR(64),
        `REFERENCED_TABLE_SCHEMA` VARCHAR(64),
        `REFERENCED_TABLE_NAME` VARCHAR(64),
        `REFERENCED_COLUMN_NAME` VARCHAR(64),
        `INVALID_KEY_COUNT` INT,
        `INVALID_KEY_SQL` VARCHAR(1024)
      );
    END IF;


    OPEN foreign_key_cursor;
    foreign_key_cursor_loop: LOOP
      FETCH foreign_key_cursor INTO
        TABLE_SCHEMA_VAR,
        TABLE_NAME_VAR,
        COLUMN_NAME_VAR,
        CONSTRAINT_NAME_VAR,
        REFERENCED_TABLE_SCHEMA_VAR,
        REFERENCED_TABLE_NAME_VAR,
        REFERENCED_COLUMN_NAME_VAR;
      IF done THEN
        LEAVE foreign_key_cursor_loop;
      END IF;


      SET @from_part = CONCAT('FROM ', '`', TABLE_SCHEMA_VAR, '`.`', TABLE_NAME_VAR, '`', ' AS REFERRING ',
                              'LEFT JOIN `', REFERENCED_TABLE_SCHEMA_VAR, '`.`', REFERENCED_TABLE_NAME_VAR, '`', ' AS REFERRED ',
                              'ON (REFERRING', '.`', COLUMN_NAME_VAR, '`', ' = ', 'REFERRED', '.`', REFERENCED_COLUMN_NAME_VAR, '`', ') ',
                              'WHERE REFERRING', '.`', COLUMN_NAME_VAR, '`', ' IS NOT NULL ',
                              'AND REFERRED', '.`', REFERENCED_COLUMN_NAME_VAR, '`', ' IS NULL');
      SET @full_query = CONCAT('SELECT COUNT(*) ', @from_part, ' INTO @invalid_key_count;');
      PREPARE stmt FROM @full_query;

      EXECUTE stmt;
      IF @invalid_key_count > 0 THEN
        INSERT INTO
          INVALID_FOREIGN_KEYS
        SET
          `TABLE_SCHEMA` = TABLE_SCHEMA_VAR,
          `TABLE_NAME` = TABLE_NAME_VAR,
          `COLUMN_NAME` = COLUMN_NAME_VAR,
          `CONSTRAINT_NAME` = CONSTRAINT_NAME_VAR,
          `REFERENCED_TABLE_SCHEMA` = REFERENCED_TABLE_SCHEMA_VAR,
          `REFERENCED_TABLE_NAME` = REFERENCED_TABLE_NAME_VAR,
          `REFERENCED_COLUMN_NAME` = REFERENCED_COLUMN_NAME_VAR,
          `INVALID_KEY_COUNT` = @invalid_key_count,
          `INVALID_KEY_SQL` = CONCAT('SELECT ',
                                     'REFERRING.', '`', COLUMN_NAME_VAR, '` ', 'AS "Invalid: ', COLUMN_NAME_VAR, '", ',
                                     'REFERRING.* ',
                                     @from_part, ';');
      END IF;
      DEALLOCATE PREPARE stmt;

    END LOOP foreign_key_cursor_loop;
  END$$

CREATE DEFINER=`root`@`app2` PROCEDURE `ANALYZE_INVALID_UNIQUE_KEYS`(
  checked_database_name VARCHAR(64),
  checked_table_name VARCHAR(64))
READS SQL DATA
  BEGIN
    DECLARE TABLE_SCHEMA_VAR VARCHAR(64);
    DECLARE TABLE_NAME_VAR VARCHAR(64);
    DECLARE COLUMN_NAMES_VAR VARCHAR(1000);
    DECLARE CONSTRAINT_NAME_VAR VARCHAR(64);

    DECLARE done INT DEFAULT 0;

    DECLARE unique_key_cursor CURSOR FOR
      select kcu.table_schema sch,
             kcu.table_name tbl,
             group_concat(kcu.column_name) colName,
             kcu.constraint_name constName
      from
        information_schema.table_constraints tc
        join
        information_schema.key_column_usage kcu
          on
            kcu.constraint_name=tc.constraint_name
            and kcu.constraint_schema=tc.constraint_schema
            and kcu.table_name=tc.table_name
      where
        kcu.table_schema like checked_database_name
        and kcu.table_name like checked_table_name
        and tc.constraint_type="UNIQUE" group by sch, tbl, constName;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    DROP TEMPORARY TABLE IF EXISTS INVALID_UNIQUE_KEYS;
    CREATE TEMPORARY TABLE INVALID_UNIQUE_KEYS(
      `TABLE_SCHEMA` VARCHAR(64),
      `TABLE_NAME` VARCHAR(64),
      `COLUMN_NAMES` VARCHAR(1000),
      `CONSTRAINT_NAME` VARCHAR(64),
      `INVALID_KEY_COUNT` INT
    );



    OPEN unique_key_cursor;
    unique_key_cursor_loop: LOOP
      FETCH unique_key_cursor INTO
        TABLE_SCHEMA_VAR,
        TABLE_NAME_VAR,
        COLUMN_NAMES_VAR,
        CONSTRAINT_NAME_VAR;
      IF done THEN
        LEAVE unique_key_cursor_loop;
      END IF;

      SET @from_part = CONCAT('FROM (SELECT COUNT(*) counter FROM', '`', TABLE_SCHEMA_VAR, '`.`', TABLE_NAME_VAR, '`',
                              ' GROUP BY ', COLUMN_NAMES_VAR , ') as s where s.counter > 1');
      SET @full_query = CONCAT('SELECT COUNT(*) ', @from_part, ' INTO @invalid_key_count;');
      PREPARE stmt FROM @full_query;
      EXECUTE stmt;
      IF @invalid_key_count > 0 THEN
        INSERT INTO
          INVALID_UNIQUE_KEYS
        SET
          `TABLE_SCHEMA` = TABLE_SCHEMA_VAR,
          `TABLE_NAME` = TABLE_NAME_VAR,
          `COLUMN_NAMES` = COLUMN_NAMES_VAR,
          `CONSTRAINT_NAME` = CONSTRAINT_NAME_VAR,
          `INVALID_KEY_COUNT` = @invalid_key_count;
      END IF;
      DEALLOCATE PREPARE stmt;

    END LOOP unique_key_cursor_loop;
  END$$

--
-- Functions
--
CREATE DEFINER=`root`@`app2` FUNCTION `GetCenterPoint`(`g` GEOMETRY) RETURNS point
NO SQL
DETERMINISTIC
  BEGIN
    DECLARE envelope POLYGON;
    DECLARE sw, ne POINT;
    DECLARE lat, lng DOUBLE;

    SET envelope = ExteriorRing(Envelope(g));
    SET sw = PointN(envelope, 1);
    SET ne = PointN(envelope, 3);
    SET lat = X(sw) + (X(ne)-X(sw))/2;
    SET lng = Y(sw) + (Y(ne)-Y(sw))/2;
    RETURN POINT(lat, lng);
  END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GetMaxDimension`(`g` GEOMETRY) RETURNS double
NO SQL
DETERMINISTIC
  BEGIN
    DECLARE area, radius, diag DOUBLE;

    SET area = AREA(g);
    SET radius = SQRT(area / PI());
    SET diag = SQRT(radius * radius * 2);
    RETURN(diag);

    /* Previous implementation returns odd geometry exceptions
    DECLARE envelope POLYGON;
    DECLARE sw, ne POINT;
    DECLARE xsize, ysize DOUBLE;

    DECLARE EXIT HANDLER FOR 1416
      RETURN(10000);

    SET envelope = ExteriorRing(Envelope(g));
    SET sw = PointN(envelope, 1);
    SET ne = PointN(envelope, 3);
    SET xsize = X(ne) - X(sw);
    SET ysize = Y(ne) - Y(sw);
    RETURN(GREATEST(xsize, ysize)); */
  END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GetMaxDimensionT`(`g` GEOMETRY) RETURNS double
NO SQL
  BEGIN
    DECLARE area, radius, diag DOUBLE;

    SET area = AREA(g);
    SET radius = SQRT(area / PI());
    SET diag = SQRT(radius * radius * 2);
    RETURN(diag);
  END$$

CREATE DEFINER=`root`@`app2` FUNCTION `haversine`(
  lat1 FLOAT, lon1 FLOAT,
  lat2 FLOAT, lon2 FLOAT
) RETURNS float
NO SQL
DETERMINISTIC
  COMMENT 'Returns the distance in degrees on the Earth\n             between two known points of latitude and longitude'
  BEGIN
    RETURN 69 * DEGREES(ACOS(
                            COS(RADIANS(lat1)) *
                            COS(RADIANS(lat2)) *
                            COS(RADIANS(lon2) - RADIANS(lon1)) +
                            SIN(RADIANS(lat1)) * SIN(RADIANS(lat2))
                        ));
  END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `abtest`
--

CREATE TABLE IF NOT EXISTS `abtest` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uid` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `variant` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `shown` bigint(20) unsigned NOT NULL,
  `action` bigint(20) unsigned NOT NULL,
  `rate` decimal(10,2) NOT NULL,
  `suggest` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uid_2` (`uid`,`variant`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='For testing site changes to see which work' AUTO_INCREMENT=1369494 ;

-- --------------------------------------------------------

--
-- Table structure for table `admins`
--

CREATE TABLE IF NOT EXISTS `admins` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `createdby` bigint(20) unsigned DEFAULT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `complete` timestamp NULL DEFAULT NULL,
  `subject` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`),
  KEY `createdby` (`createdby`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Try all means to reach people with these' AUTO_INCREMENT=3110 ;

-- --------------------------------------------------------

--
-- Table structure for table `alerts`
--

CREATE TABLE IF NOT EXISTS `alerts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `createdby` bigint(20) unsigned DEFAULT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `from` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `to` enum('Users','Mods') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Mods',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `groupprogress` bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'For alerts to multiple groups',
  `complete` timestamp NULL DEFAULT NULL,
  `subject` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `html` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `askclick` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether to ask them to click to confirm receipt',
  `tryhard` tinyint(4) NOT NULL DEFAULT '1' COMMENT 'Whether to mail all mods addresses too',
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`),
  KEY `createdby` (`createdby`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Try all means to reach people with these' AUTO_INCREMENT=6746 ;

-- --------------------------------------------------------

--
-- Table structure for table `alerts_tracking`
--

CREATE TABLE IF NOT EXISTS `alerts_tracking` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `alertid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `emailid` bigint(20) unsigned DEFAULT NULL,
  `type` enum('ModEmail','OwnerEmail','PushNotif','ModToolsNotif') COLLATE utf8mb4_unicode_ci NOT NULL,
  `sent` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `responded` timestamp NULL DEFAULT NULL,
  `response` enum('Read','Clicked','Bounce','Unsubscribe') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`),
  KEY `alertid` (`alertid`),
  KEY `emailid` (`emailid`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=142100 ;

-- --------------------------------------------------------

--
-- Table structure for table `authorities`
--

CREATE TABLE IF NOT EXISTS `authorities` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `polygon` geometry NOT NULL,
  `simplified` geometry DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  SPATIAL KEY `polygon` (`polygon`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Counties and Unitary Authorities.  May be multigeometries' AUTO_INCREMENT=827 ;

-- --------------------------------------------------------

--
-- Table structure for table `bounces`
--

CREATE TABLE IF NOT EXISTS `bounces` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `to` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `msg` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bounce messages received by email' AUTO_INCREMENT=10541680 ;

-- --------------------------------------------------------

--
-- Table structure for table `bounces_emails`
--

CREATE TABLE IF NOT EXISTS `bounces_emails` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `emailid` bigint(20) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reason` text COLLATE utf8mb4_unicode_ci,
  `permanent` tinyint(1) NOT NULL DEFAULT '0',
  `reset` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'If we have reset bounces for this email',
  PRIMARY KEY (`id`),
  KEY `emailid` (`emailid`,`date`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=16209821 ;

-- --------------------------------------------------------

--
-- Table structure for table `chat_images`
--

CREATE TABLE IF NOT EXISTS `chat_images` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `chatmsgid` bigint(20) unsigned DEFAULT NULL,
  `contenttype` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `archived` tinyint(4) DEFAULT '0',
  `data` longblob,
  `identification` mediumtext COLLATE utf8mb4_unicode_ci,
  `hash` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `incomingid` (`chatmsgid`),
  KEY `hash` (`hash`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16 COMMENT='Attachments parsed out from messages and resized' AUTO_INCREMENT=41348 ;

-- --------------------------------------------------------

--
-- Table structure for table `chat_messages`
--

CREATE TABLE IF NOT EXISTS `chat_messages` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `chatid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned NOT NULL COMMENT 'From',
  `type` enum('Default','System','ModMail','Interested','Promised','Reneged','ReportedUser','Completed','Image','Address','Nudge','Schedule','ScheduleUpdated') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Default',
  `reportreason` enum('Spam','Other') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `refmsgid` bigint(20) unsigned DEFAULT NULL,
  `refchatid` bigint(20) unsigned DEFAULT NULL,
  `imageid` bigint(20) unsigned DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `message` text COLLATE utf8mb4_unicode_ci,
  `platform` tinyint(4) NOT NULL DEFAULT '1' COMMENT 'Whether this was created on the platform vs email',
  `seenbyall` tinyint(1) NOT NULL DEFAULT '0',
  `mailedtoall` tinyint(1) NOT NULL DEFAULT '0',
  `reviewrequired` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether a volunteer should review before it''s passed on',
  `reviewedby` bigint(20) unsigned DEFAULT NULL COMMENT 'User id of volunteer who reviewed it',
  `reviewrejected` tinyint(1) NOT NULL DEFAULT '0',
  `spamscore` int(11) DEFAULT NULL COMMENT 'SpamAssassin score for mail replies',
  `facebookid` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `scheduleid` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `chatid` (`chatid`),
  KEY `userid` (`userid`),
  KEY `chatid_2` (`chatid`,`date`),
  KEY `msgid` (`refmsgid`),
  KEY `date` (`date`,`seenbyall`),
  KEY `reviewedby` (`reviewedby`),
  KEY `reviewrequired` (`reviewrequired`),
  KEY `refchatid` (`refchatid`),
  KEY `refchatid_2` (`refchatid`),
  KEY `imageid` (`imageid`),
  KEY `scheduleid` (`scheduleid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=8718547 ;

-- --------------------------------------------------------

--
-- Table structure for table `chat_rooms`
--

CREATE TABLE IF NOT EXISTS `chat_rooms` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `chattype` enum('Mod2Mod','User2Mod','User2User','Group') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'User2User',
  `groupid` bigint(20) unsigned DEFAULT NULL COMMENT 'Restricted to a group',
  `user1` bigint(20) unsigned DEFAULT NULL COMMENT 'For DMs',
  `user2` bigint(20) unsigned DEFAULT NULL COMMENT 'For DMs',
  `description` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `synctofacebook` enum('Dont','RepliedOnFacebook','RepliedOnPlatform','PostedLink') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Dont',
  `synctofacebookgroupid` bigint(20) unsigned DEFAULT NULL,
  `latestmessage` timestamp NULL DEFAULT NULL COMMENT 'Loosely up to date - cron',
  `msgvalid` int(10) unsigned NOT NULL DEFAULT '0',
  `msginvalid` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user1_2` (`user1`,`user2`,`chattype`),
  KEY `user1` (`user1`),
  KEY `user2` (`user2`),
  KEY `synctofacebook` (`synctofacebook`),
  KEY `synctofacebookgroupid` (`synctofacebookgroupid`),
  KEY `chattype` (`chattype`),
  KEY `groupid` (`groupid`),
  KEY `chattype_2` (`chattype`),
  KEY `chattype_3` (`chattype`),
  KEY `chattype_4` (`chattype`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=2930857 ;

-- --------------------------------------------------------

--
-- Table structure for table `chat_roster`
--

CREATE TABLE IF NOT EXISTS `chat_roster` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `chatid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` enum('Online','Away','Offline','Closed','Blocked') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Online',
  `lastmsgseen` bigint(20) unsigned DEFAULT NULL,
  `lastemailed` timestamp NULL DEFAULT NULL,
  `lastmsgemailed` bigint(20) unsigned DEFAULT NULL,
  `lastip` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `chatid_2` (`chatid`,`userid`),
  KEY `chatid` (`chatid`),
  KEY `userid` (`userid`),
  KEY `date` (`date`),
  KEY `lastmsg` (`lastmsgseen`),
  KEY `lastip` (`lastip`),
  KEY `status` (`status`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=300290998 ;

-- --------------------------------------------------------

--
-- Table structure for table `communityevents`
--

CREATE TABLE IF NOT EXISTS `communityevents` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `pending` tinyint(1) NOT NULL DEFAULT '0',
  `title` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `contactname` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contactphone` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contactemail` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contacturl` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` tinyint(4) NOT NULL DEFAULT '0',
  `legacyid` bigint(20) unsigned DEFAULT NULL COMMENT 'For migration from FDv1',
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`),
  KEY `title` (`title`),
  KEY `legacyid` (`legacyid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=129902 ;

-- --------------------------------------------------------

--
-- Table structure for table `communityevents_dates`
--

CREATE TABLE IF NOT EXISTS `communityevents_dates` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `eventid` bigint(20) unsigned NOT NULL,
  `start` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `end` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`),
  KEY `start` (`start`),
  KEY `eventid` (`eventid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=124769 ;

-- --------------------------------------------------------

--
-- Table structure for table `communityevents_groups`
--

CREATE TABLE IF NOT EXISTS `communityevents_groups` (
  `eventid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `arrival` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `eventid_2` (`eventid`,`groupid`),
  KEY `eventid` (`eventid`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `communityevents_images`
--

CREATE TABLE IF NOT EXISTS `communityevents_images` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `eventid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the community events table',
  `contenttype` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `archived` tinyint(4) DEFAULT '0',
  `data` longblob,
  `identification` mediumtext COLLATE utf8mb4_unicode_ci,
  `hash` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `incomingid` (`eventid`),
  KEY `hash` (`hash`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16 COMMENT='Attachments parsed out from messages and resized' AUTO_INCREMENT=4118 ;

-- --------------------------------------------------------

--
-- Table structure for table `ebay_favourites`
--

CREATE TABLE IF NOT EXISTS `ebay_favourites` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `count` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=2338 ;

-- --------------------------------------------------------

--
-- Table structure for table `groups`
--

CREATE TABLE IF NOT EXISTS `groups` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID of group',
  `legacyid` bigint(20) unsigned DEFAULT NULL COMMENT '(Freegle) Groupid on old system',
  `nameshort` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'A short name for the group',
  `namefull` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'A longer name for the group',
  `nameabbr` varchar(5) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'An abbreviated name for the group',
  `namealt` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Alternative name, e.g. as used by GAT',
  `settings` longtext COLLATE utf8mb4_unicode_ci COMMENT 'JSON-encoded settings for group',
  `type` set('Reuse','Freegle','Other','UnitTest') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Other' COMMENT 'High-level characteristics of the group',
  `region` enum('East','East Midlands','West Midlands','North East','North West','Northern Ireland','South East','South West','London','Wales','Yorkshire and the Humber','Scotland') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Freegle only',
  `authorityid` bigint(20) unsigned DEFAULT NULL,
  `onyahoo` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether this group is also on Yahoo Groups',
  `onhere` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'Whether this group is available on this platform',
  `ontn` tinyint(1) NOT NULL DEFAULT '0',
  `showonyahoo` tinyint(1) NOT NULL DEFAULT '1' COMMENT '(Freegle) Whether to show Yahoo links',
  `lastyahoomembersync` timestamp NULL DEFAULT NULL COMMENT 'When we last synced approved members',
  `lastyahoomessagesync` timestamp NULL DEFAULT NULL COMMENT 'When we last synced approved messages',
  `lat` decimal(10,6) DEFAULT NULL,
  `lng` decimal(10,6) DEFAULT NULL,
  `poly` longtext COLLATE utf8mb4_unicode_ci COMMENT 'Any polygon defining core area',
  `polyofficial` longtext COLLATE utf8mb4_unicode_ci COMMENT 'If present, GAT area and poly is catchment',
  `confirmkey` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Key used to verify some operations by email',
  `publish` tinyint(4) NOT NULL DEFAULT '1' COMMENT '(Freegle) Whether this group is visible to members',
  `listable` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Whether shows up in groups API call',
  `onmap` tinyint(4) NOT NULL DEFAULT '1' COMMENT '(Freegle) Whether to show on the map of groups',
  `licenserequired` tinyint(4) DEFAULT '1' COMMENT 'Whether a license is required for this group',
  `trial` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'For ModTools, when a trial was started',
  `licensed` date DEFAULT NULL COMMENT 'For ModTools, when a group was licensed',
  `licenseduntil` date DEFAULT NULL COMMENT 'For ModTools, when a group is licensed until',
  `membercount` int(11) NOT NULL DEFAULT '0' COMMENT 'Automatically refreshed',
  `modcount` int(11) NOT NULL DEFAULT '0',
  `profile` bigint(20) unsigned DEFAULT NULL,
  `cover` bigint(20) unsigned DEFAULT NULL,
  `tagline` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '(Freegle) One liner slogan for this group',
  `description` text COLLATE utf8mb4_unicode_ci,
  `founded` date DEFAULT NULL,
  `lasteventsroundup` timestamp NULL DEFAULT NULL COMMENT '(Freegle) Last event roundup sent',
  `lastvolunteeringroundup` timestamp NULL DEFAULT NULL,
  `external` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Link to some other system e.g. Norfolk',
  `contactmail` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For external sites',
  `welcomemail` text COLLATE utf8mb4_unicode_ci COMMENT '(Freegle) Text for welcome mail',
  `activitypercent` decimal(10,2) DEFAULT NULL COMMENT 'Within a group type, the proportion of overall activity that this group accounts for.',
  `fundingtarget` int(11) NOT NULL DEFAULT '0',
  `lastmoderated` timestamp NULL DEFAULT NULL COMMENT 'Last moderated inc Yahoo',
  `lastmodactive` timestamp NULL DEFAULT NULL COMMENT 'Last mod active on here',
  `activemodcount` int(11) DEFAULT NULL COMMENT 'How many currently active mods',
  `backupownersactive` int(11) NOT NULL DEFAULT '0',
  `backupmodsactive` int(11) NOT NULL DEFAULT '0',
  `lastautoapprove` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `nameshort` (`nameshort`),
  UNIQUE KEY `namefull` (`namefull`),
  KEY `lat` (`lat`,`lng`),
  KEY `lng` (`lng`),
  KEY `namealt` (`namealt`),
  KEY `profile` (`profile`),
  KEY `cover` (`cover`),
  KEY `legacyid` (`legacyid`),
  KEY `authorityid` (`authorityid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='The different groups that we host' AUTO_INCREMENT=431243 ;

-- --------------------------------------------------------

--
-- Table structure for table `groups_digests`
--

CREATE TABLE IF NOT EXISTS `groups_digests` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `groupid` bigint(20) unsigned NOT NULL,
  `frequency` int(11) NOT NULL,
  `msgid` bigint(20) unsigned DEFAULT NULL COMMENT 'Which message we got upto when sending',
  `msgdate` timestamp(6) NULL DEFAULT NULL COMMENT 'Arrival of message we have sent upto',
  `started` timestamp NULL DEFAULT NULL,
  `ended` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `groupid_2` (`groupid`,`frequency`),
  KEY `groupid` (`groupid`),
  KEY `msggrpid` (`msgid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=309573541 ;

-- --------------------------------------------------------

--
-- Table structure for table `groups_facebook`
--

CREATE TABLE IF NOT EXISTS `groups_facebook` (
  `uid` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `groupid` bigint(20) unsigned NOT NULL,
  `name` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` enum('Page','Group') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Page',
  `id` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `token` text COLLATE utf8mb4_unicode_ci,
  `authdate` timestamp NULL DEFAULT NULL,
  `msgid` bigint(20) unsigned DEFAULT NULL COMMENT 'Last message posted',
  `msgarrival` timestamp NULL DEFAULT NULL COMMENT 'Time of last message posted',
  `eventid` bigint(20) unsigned DEFAULT NULL COMMENT 'Last event tweeted',
  `valid` tinyint(4) NOT NULL DEFAULT '1',
  `lasterror` text COLLATE utf8mb4_unicode_ci,
  `lasterrortime` timestamp NULL DEFAULT NULL,
  `sharefrom` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT '134117207097' COMMENT 'Facebook page to republish from',
  `lastupdated` timestamp NULL DEFAULT NULL COMMENT 'From Graph API',
  PRIMARY KEY (`uid`),
  UNIQUE KEY `groupid_2` (`groupid`,`id`),
  KEY `msgid` (`msgid`),
  KEY `eventid` (`eventid`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1142 ;

-- --------------------------------------------------------

--
-- Table structure for table `groups_facebook_shares`
--

CREATE TABLE IF NOT EXISTS `groups_facebook_shares` (
  `uid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `postid` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` enum('Shared','Hidden','','') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Shared',
  UNIQUE KEY `groupid` (`uid`,`postid`),
  KEY `date` (`date`),
  KEY `postid` (`postid`),
  KEY `uid` (`uid`),
  KEY `groupid_2` (`groupid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `groups_facebook_toshare`
--

CREATE TABLE IF NOT EXISTS `groups_facebook_toshare` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `sharefrom` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Page to share from',
  `postid` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Facebook postid',
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `data` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `postid` (`postid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Stores central posts for sharing out to group pages' AUTO_INCREMENT=8302514 ;

-- --------------------------------------------------------

--
-- Table structure for table `groups_images`
--

CREATE TABLE IF NOT EXISTS `groups_images` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `groupid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the groups table',
  `contenttype` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `archived` tinyint(4) DEFAULT '0',
  `data` longblob,
  `identification` mediumtext COLLATE utf8mb4_unicode_ci,
  `hash` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `incomingid` (`groupid`),
  KEY `hash` (`hash`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16 COMMENT='Attachments parsed out from messages and resized' AUTO_INCREMENT=3722 ;

-- --------------------------------------------------------

--
-- Table structure for table `groups_twitter`
--

CREATE TABLE IF NOT EXISTS `groups_twitter` (
  `groupid` bigint(20) unsigned NOT NULL,
  `name` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `token` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `secret` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `authdate` timestamp NULL DEFAULT NULL,
  `msgid` bigint(20) unsigned DEFAULT NULL COMMENT 'Last message tweeted',
  `msgarrival` timestamp NULL DEFAULT NULL,
  `eventid` bigint(20) unsigned DEFAULT NULL COMMENT 'Last event tweeted',
  `valid` tinyint(4) NOT NULL DEFAULT '1',
  `locked` tinyint(1) NOT NULL DEFAULT '0',
  `lasterror` text COLLATE utf8mb4_unicode_ci,
  `lasterrortime` timestamp NULL DEFAULT NULL,
  UNIQUE KEY `groupid` (`groupid`),
  KEY `msgid` (`msgid`),
  KEY `eventid` (`eventid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `items`
--

CREATE TABLE IF NOT EXISTS `items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `popularity` int(11) NOT NULL DEFAULT '0',
  `weight` decimal(10,2) DEFAULT NULL,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `suggestfromphoto` tinyint(4) NOT NULL DEFAULT '1' COMMENT 'We can exclude from image recognition',
  `suggestfromtypeahead` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'We can exclude from typeahead',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=1729168 ;

-- --------------------------------------------------------

--
-- Table structure for table `items_index`
--

CREATE TABLE IF NOT EXISTS `items_index` (
  `itemid` bigint(20) unsigned NOT NULL,
  `wordid` bigint(20) unsigned NOT NULL,
  `popularity` int(11) NOT NULL DEFAULT '0',
  `categoryid` bigint(20) unsigned DEFAULT NULL,
  UNIQUE KEY `itemid` (`itemid`,`wordid`),
  KEY `itemid_2` (`itemid`),
  KEY `wordid` (`wordid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `items_non`
--

CREATE TABLE IF NOT EXISTS `items_non` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `popularity` int(11) NOT NULL DEFAULT '1',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `lastexample` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Not considered items by us, but by image recognition' AUTO_INCREMENT=2188214 ;

-- --------------------------------------------------------

--
-- Table structure for table `link_previews`
--

CREATE TABLE IF NOT EXISTS `link_previews` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `url` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `image` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invalid` tinyint(1) NOT NULL DEFAULT '0',
  `spam` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `url` (`url`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1106 ;

-- --------------------------------------------------------

--
-- Table structure for table `locations`
--

CREATE TABLE IF NOT EXISTS `locations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `osm_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('Road','Polygon','Line','Point','Postcode') COLLATE utf8mb4_unicode_ci NOT NULL,
  `osm_place` tinyint(1) DEFAULT '0',
  `geometry` geometry DEFAULT NULL,
  `ourgeometry` geometry DEFAULT NULL COMMENT 'geometry comes from OSM; this comes from us',
  `gridid` bigint(20) unsigned DEFAULT NULL,
  `postcodeid` bigint(20) unsigned DEFAULT NULL,
  `areaid` bigint(20) unsigned DEFAULT NULL,
  `canon` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `popularity` bigint(20) unsigned DEFAULT '0',
  `osm_amenity` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'For OSM locations, whether this is an amenity',
  `osm_shop` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'For OSM locations, whether this is a shop',
  `maxdimension` decimal(10,6) DEFAULT NULL COMMENT 'GetMaxDimension on geomtry',
  `lat` decimal(10,6) DEFAULT NULL,
  `lng` decimal(10,6) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `name` (`name`),
  KEY `osm_id` (`osm_id`),
  KEY `canon` (`canon`),
  KEY `areaid` (`areaid`),
  KEY `postcodeid` (`postcodeid`),
  KEY `lat` (`lat`),
  KEY `lng` (`lng`),
  KEY `gridid` (`gridid`,`osm_place`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Location data, the bulk derived from OSM' AUTO_INCREMENT=9440993 ;

-- --------------------------------------------------------

--
-- Table structure for table `locations_excluded`
--

CREATE TABLE IF NOT EXISTS `locations_excluded` (
  `locationid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `locationid_2` (`locationid`,`groupid`),
  KEY `locationid` (`locationid`),
  KEY `groupid` (`groupid`),
  KEY `by` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Stops locations being suggested on a group';

-- --------------------------------------------------------

--
-- Table structure for table `locations_grids`
--

CREATE TABLE IF NOT EXISTS `locations_grids` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `swlat` decimal(10,6) NOT NULL,
  `swlng` decimal(10,6) NOT NULL,
  `nelat` decimal(10,6) NOT NULL,
  `nelng` decimal(10,6) NOT NULL,
  `box` geometry NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `swlat` (`swlat`,`swlng`,`nelat`,`nelng`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Used to map lat/lng to gridid for location searches' AUTO_INCREMENT=701708 ;

-- --------------------------------------------------------

--
-- Table structure for table `locations_grids_touches`
--

CREATE TABLE IF NOT EXISTS `locations_grids_touches` (
  `gridid` bigint(20) unsigned NOT NULL,
  `touches` bigint(20) unsigned NOT NULL,
  UNIQUE KEY `gridid` (`gridid`,`touches`),
  KEY `touches` (`touches`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='A record of which grid squares touch others';

-- --------------------------------------------------------

--
-- Table structure for table `locations_spatial`
--

CREATE TABLE IF NOT EXISTS `locations_spatial` (
  `locationid` bigint(20) unsigned NOT NULL,
  `geometry` geometry NOT NULL,
  UNIQUE KEY `locationid` (`locationid`),
  SPATIAL KEY `geometry` (`geometry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `logs`
--

CREATE TABLE IF NOT EXISTS `logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Machine assumed set to GMT',
  `byuser` bigint(20) unsigned DEFAULT NULL COMMENT 'User responsible for action, if any',
  `type` enum('Group','Message','User','Plugin','Config','StdMsg','Location','BulkOp') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `subtype` enum('Created','Deleted','Received','Sent','Failure','ClassifiedSpam','Joined','Left','Approved','Rejected','YahooDeliveryType','YahooPostingStatus','NotSpam','Login','Hold','Release','Edit','RoleChange','Merged','Split','Replied','Mailed','Applied','Suspect','Licensed','LicensePurchase','YahooApplied','YahooConfirmed','YahooJoined','MailOff','EventsOff','NewslettersOff','RelevantOff','Logout','Bounce','SuspendMail','Autoreposted','Outcome','OurPostingStatus','OurPostingStatus','VolunteersOff','Autoapproved','Unbounce') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL COMMENT 'Any group this log is for',
  `user` bigint(20) unsigned DEFAULT NULL COMMENT 'Any user that this log is about',
  `msgid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the messages table',
  `configid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the mod_configs table',
  `stdmsgid` bigint(20) unsigned DEFAULT NULL COMMENT 'Any stdmsg for this log',
  `bulkopid` bigint(20) unsigned DEFAULT NULL,
  `text` mediumtext COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `group` (`groupid`),
  KEY `type` (`type`,`subtype`),
  KEY `timestamp` (`timestamp`),
  KEY `byuser` (`byuser`),
  KEY `user` (`user`),
  KEY `msgid` (`msgid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Logs.  Not guaranteed against loss' AUTO_INCREMENT=130577983 ;

-- --------------------------------------------------------

--
-- Table structure for table `logs_api`
--

CREATE TABLE IF NOT EXISTS `logs_api` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `userid` bigint(20) DEFAULT NULL,
  `ip` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `session` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `request` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `response` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `session` (`session`),
  KEY `date` (`date`),
  KEY `userid` (`userid`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC KEY_BLOCK_SIZE=8 COMMENT='Log of all API requests and responses' AUTO_INCREMENT=4302787 ;

-- --------------------------------------------------------

--
-- Table structure for table `logs_emails`
--

CREATE TABLE IF NOT EXISTS `logs_emails` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `eximid` varchar(12) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `from` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `to` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `messageid` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `timestamp_2` (`eximid`),
  KEY `timestamp` (`timestamp`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=3144859 ;

-- --------------------------------------------------------

--
-- Table structure for table `logs_errors`
--

CREATE TABLE IF NOT EXISTS `logs_errors` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('Exception') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `userid` bigint(20) DEFAULT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Errors from client' AUTO_INCREMENT=6162292 ;

-- --------------------------------------------------------

--
-- Table structure for table `logs_events`
--

CREATE TABLE IF NOT EXISTS `logs_events` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `sessionid` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ip` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `timestamp` timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `clienttimestamp` timestamp(3) NOT NULL DEFAULT '0000-00-00 00:00:00.000',
  `posx` int(11) DEFAULT NULL,
  `posy` int(11) DEFAULT NULL,
  `viewx` int(11) DEFAULT NULL,
  `viewy` int(11) DEFAULT NULL,
  `data` mediumtext COLLATE utf8mb4_unicode_ci,
  `datasameas` bigint(20) unsigned DEFAULT NULL COMMENT 'Allows use to reuse data stored in table once for other rows',
  `datahash` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `route` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `event` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`,`timestamp`),
  KEY `sessionid` (`sessionid`),
  KEY `datasameas` (`datasameas`),
  KEY `datahash` (`datahash`,`datasameas`),
  KEY `ip` (`ip`),
  KEY `timestamp` (`timestamp`),
  KEY `sessionid_2` (`sessionid`,`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `logs_profile`
--

CREATE TABLE IF NOT EXISTS `logs_profile` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `caller` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `callee` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ct` bigint(20) unsigned NOT NULL DEFAULT '0',
  `wt` bigint(20) unsigned NOT NULL DEFAULT '0',
  `cpu` bigint(20) unsigned NOT NULL,
  `mu` bigint(20) unsigned NOT NULL,
  `pmu` bigint(20) unsigned NOT NULL,
  `alloc` bigint(20) unsigned NOT NULL,
  `free` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `caller` (`caller`,`callee`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `logs_sql`
--

CREATE TABLE IF NOT EXISTS `logs_sql` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `duration` decimal(15,10) unsigned DEFAULT '0.0000000000' COMMENT 'seconds',
  `userid` bigint(20) unsigned DEFAULT NULL,
  `session` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `request` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `response` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'rc:lastInsertId',
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `session` (`session`),
  KEY `date` (`date`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8 COMMENT='Log of modification SQL operations' AUTO_INCREMENT=26578915 ;

-- --------------------------------------------------------

--
-- Table structure for table `logs_src`
--

CREATE TABLE IF NOT EXISTS `logs_src` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `src` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `session` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `date` (`date`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Record which mails we sent generated website traffic' AUTO_INCREMENT=22844179 ;

-- --------------------------------------------------------

--
-- Table structure for table `memberships`
--

CREATE TABLE IF NOT EXISTS `memberships` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `role` enum('Member','Moderator','Owner') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Member',
  `collection` enum('Approved','Pending','Banned') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Approved',
  `configid` bigint(20) unsigned DEFAULT NULL COMMENT 'Configuration used to moderate this group if a moderator',
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `settings` mediumtext COLLATE utf8mb4_unicode_ci COMMENT 'Other group settings, e.g. for moderators',
  `syncdelete` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'Used during member sync',
  `heldby` bigint(20) unsigned DEFAULT NULL,
  `emailfrequency` int(11) NOT NULL DEFAULT '24' COMMENT 'In hours; -1 immediately, 0 never',
  `eventsallowed` tinyint(1) DEFAULT '1',
  `volunteeringallowed` bigint(20) NOT NULL DEFAULT '1',
  `ourPostingStatus` enum('MODERATED','DEFAULT','PROHIBITED','UNMODERATED') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For Yahoo groups, NULL; for ours, the posting status',
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid_groupid` (`userid`,`groupid`),
  KEY `groupid_2` (`groupid`,`role`),
  KEY `userid` (`userid`,`role`),
  KEY `role` (`role`),
  KEY `configid` (`configid`),
  KEY `groupid` (`groupid`,`collection`),
  KEY `heldby` (`heldby`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Which groups users are members of' AUTO_INCREMENT=41844604 ;

-- --------------------------------------------------------

--
-- Table structure for table `memberships_history`
--

CREATE TABLE IF NOT EXISTS `memberships_history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `collection` enum('Approved','Pending','Banned') COLLATE utf8mb4_unicode_ci NOT NULL,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`),
  KEY `date` (`added`),
  KEY `userid` (`userid`,`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Used to spot multijoiners' AUTO_INCREMENT=33017722 ;

-- --------------------------------------------------------

--
-- Table structure for table `memberships_yahoo`
--

CREATE TABLE IF NOT EXISTS `memberships_yahoo` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `membershipid` bigint(20) unsigned NOT NULL,
  `role` enum('Member','Moderator','Owner') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Member',
  `collection` enum('Approved','Pending','Banned') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Approved',
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `emailid` bigint(20) unsigned NOT NULL COMMENT 'Which of their emails they use on this group',
  `yahooAlias` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `yahooPostingStatus` enum('MODERATED','DEFAULT','PROHIBITED','UNMODERATED') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Yahoo mod status if applicable',
  `yahooDeliveryType` enum('DIGEST','NONE','SINGLE','ANNOUNCEMENT') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Yahoo delivery settings if applicable',
  `syncdelete` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'Used during member sync',
  `yahooapprove` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For Yahoo groups, email to approve member if known and relevant',
  `yahooreject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For Yahoo groups, email to reject member if known and relevant',
  `joincomment` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Any joining comment for this member',
  PRIMARY KEY (`id`),
  UNIQUE KEY `membershipid_2` (`membershipid`,`emailid`),
  KEY `role` (`role`),
  KEY `emailid` (`emailid`),
  KEY `groupid` (`collection`),
  KEY `yahooPostingStatus` (`yahooPostingStatus`),
  KEY `yahooDeliveryType` (`yahooDeliveryType`),
  KEY `yahooAlias` (`yahooAlias`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Which groups users are members of' AUTO_INCREMENT=24774328 ;

-- --------------------------------------------------------

--
-- Table structure for table `memberships_yahoo_dump`
--

CREATE TABLE IF NOT EXISTS `memberships_yahoo_dump` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `groupid` bigint(20) unsigned NOT NULL,
  `members` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `lastupdated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `lastprocessed` timestamp NULL DEFAULT NULL COMMENT 'When this was last processed into the main tables',
  `synctime` timestamp NULL DEFAULT NULL COMMENT 'Time on client when sync started',
  `backgroundok` tinyint(4) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `groupid` (`groupid`),
  KEY `lastprocessed` (`lastprocessed`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16 COMMENT='Copy of last member sync from Yahoo' AUTO_INCREMENT=854441 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages`
--

CREATE TABLE IF NOT EXISTS `messages` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique iD',
  `arrival` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this message arrived at our server',
  `date` timestamp NULL DEFAULT NULL COMMENT 'When this message was created, e.g. Date header',
  `deleted` timestamp NULL DEFAULT NULL COMMENT 'When this message was deleted',
  `heldby` bigint(20) unsigned DEFAULT NULL COMMENT 'If this message is held by a moderator',
  `source` enum('Yahoo Approved','Yahoo Pending','Yahoo System','Platform','Email') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Source of incoming message',
  `sourceheader` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Any source header, e.g. X-Freegle-Source',
  `fromip` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'IP we think this message came from',
  `fromcountry` varchar(2) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'fromip geocoded to country',
  `message` longtext COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'The unparsed message',
  `fromuser` bigint(20) unsigned DEFAULT NULL,
  `envelopefrom` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fromname` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fromaddr` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `envelopeto` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `replyto` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suggestedsubject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` enum('Offer','Taken','Wanted','Received','Admin','Other') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For reuse groups, the message categorisation',
  `messageid` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tnpostid` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'If this message came from Trash Nothing, the unique post ID',
  `textbody` longtext COLLATE utf8mb4_unicode_ci,
  `htmlbody` longtext COLLATE utf8mb4_unicode_ci,
  `retrycount` int(11) NOT NULL DEFAULT '0' COMMENT 'We might fail to route, and later retry',
  `retrylastfailure` timestamp NULL DEFAULT NULL,
  `spamtype` enum('CountryBlocked','IPUsedForDifferentUsers','IPUsedForDifferentGroups','SubjectUsedForDifferentGroups','SpamAssassin','NotSpam') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `spamreason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Why we think this message may be spam',
  `lat` decimal(10,6) DEFAULT NULL,
  `lng` decimal(10,6) DEFAULT NULL,
  `locationid` bigint(20) unsigned DEFAULT NULL,
  `editedby` bigint(20) unsigned DEFAULT NULL,
  `editedat` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `message-id` (`messageid`) KEY_BLOCK_SIZE=16,
  KEY `envelopefrom` (`envelopefrom`),
  KEY `envelopeto` (`envelopeto`),
  KEY `retrylastfailure` (`retrylastfailure`),
  KEY `fromup` (`fromip`),
  KEY `tnpostid` (`tnpostid`),
  KEY `type` (`type`),
  KEY `sourceheader` (`sourceheader`),
  KEY `arrival` (`arrival`,`sourceheader`),
  KEY `arrival_2` (`arrival`,`fromaddr`),
  KEY `arrival_3` (`arrival`),
  KEY `fromaddr` (`fromaddr`,`subject`),
  KEY `date` (`date`),
  KEY `subject` (`subject`),
  KEY `fromuser` (`fromuser`),
  KEY `deleted` (`deleted`),
  KEY `heldby` (`heldby`),
  KEY `lat` (`lat`) KEY_BLOCK_SIZE=16,
  KEY `lng` (`lng`) KEY_BLOCK_SIZE=16,
  KEY `locationid` (`locationid`) KEY_BLOCK_SIZE=16
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8 COMMENT='All our messages' AUTO_INCREMENT=28428688 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_attachments`
--

CREATE TABLE IF NOT EXISTS `messages_attachments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `msgid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the messages table',
  `contenttype` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `archived` tinyint(4) DEFAULT '0',
  `data` longblob,
  `identification` mediumtext COLLATE utf8mb4_unicode_ci,
  `hash` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `incomingid` (`msgid`),
  KEY `hash` (`hash`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16 COMMENT='Attachments parsed out from messages and resized' AUTO_INCREMENT=7279006 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_attachments_items`
--

CREATE TABLE IF NOT EXISTS `messages_attachments_items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `attid` bigint(20) unsigned NOT NULL,
  `itemid` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `msgid` (`attid`),
  KEY `itemid` (`itemid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=1687358 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_deadlines`
--

CREATE TABLE IF NOT EXISTS `messages_deadlines` (
  `msgid` bigint(20) unsigned NOT NULL,
  `FOP` tinyint(4) NOT NULL DEFAULT '1',
  `mustgoby` date DEFAULT NULL,
  UNIQUE KEY `msgid` (`msgid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `messages_drafts`
--

CREATE TABLE IF NOT EXISTS `messages_drafts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `msgid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `session` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `msgid` (`msgid`),
  KEY `userid` (`userid`),
  KEY `session` (`session`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=1268908 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_groups`
--

CREATE TABLE IF NOT EXISTS `messages_groups` (
  `msgid` bigint(20) unsigned NOT NULL COMMENT 'id in the messages table',
  `groupid` bigint(20) unsigned NOT NULL,
  `collection` enum('Incoming','Pending','Approved','Spam','QueuedYahooUser','Rejected') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `arrival` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `autoreposts` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'How many times this message has been auto-reposted',
  `lastautopostwarning` timestamp NULL DEFAULT NULL,
  `lastchaseup` timestamp NULL DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `senttoyahoo` tinyint(1) NOT NULL DEFAULT '0',
  `yahoopendingid` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For Yahoo messages, pending id if relevant',
  `yahooapprovedid` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For Yahoo messages, approved id if relevant',
  `yahooapprove` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For Yahoo messages, email to trigger approve if relevant',
  `yahooreject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For Yahoo messages, email to trigger reject if relevant',
  `approvedby` bigint(20) unsigned DEFAULT NULL COMMENT 'Mod who approved this post (if any)',
  `approvedat` timestamp NULL DEFAULT NULL,
  `rejectedat` timestamp NULL DEFAULT NULL,
  `msgtype` enum('Offer','Taken','Wanted','Received','Admin','Other') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'In here for performance optimisation',
  UNIQUE KEY `msgid` (`msgid`,`groupid`),
  UNIQUE KEY `groupid_3` (`groupid`,`yahooapprovedid`),
  UNIQUE KEY `groupid_2` (`groupid`,`yahoopendingid`),
  KEY `messageid` (`msgid`,`groupid`,`collection`,`arrival`),
  KEY `collection` (`collection`),
  KEY `approvedby` (`approvedby`),
  KEY `groupid` (`groupid`,`collection`,`deleted`,`arrival`),
  KEY `arrival` (`arrival`,`groupid`),
  KEY `deleted` (`deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='The state of the message on each group';

-- --------------------------------------------------------

--
-- Table structure for table `messages_history`
--

CREATE TABLE IF NOT EXISTS `messages_history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique iD',
  `msgid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the messages table',
  `arrival` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this message arrived at our server',
  `source` enum('Yahoo Approved','Yahoo Pending','Yahoo System','Platform') CHARACTER SET latin1 DEFAULT NULL COMMENT 'Source of incoming message',
  `fromip` varchar(40) CHARACTER SET latin1 DEFAULT NULL COMMENT 'IP we think this message came from',
  `fromhost` varchar(80) CHARACTER SET latin1 DEFAULT NULL COMMENT 'Hostname for fromip if resolvable, or NULL',
  `fromuser` bigint(20) unsigned DEFAULT NULL,
  `envelopefrom` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `fromname` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `fromaddr` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `envelopeto` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL COMMENT 'Destination group, if identified',
  `subject` varchar(1024) CHARACTER SET latin1 DEFAULT NULL,
  `prunedsubject` varchar(1024) CHARACTER SET latin1 DEFAULT NULL COMMENT 'For spam detection',
  `messageid` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `repost` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `msgid` (`msgid`,`groupid`),
  KEY `fromaddr` (`fromaddr`),
  KEY `envelopefrom` (`envelopefrom`),
  KEY `envelopeto` (`envelopeto`),
  KEY `message-id` (`messageid`),
  KEY `groupid` (`groupid`),
  KEY `fromup` (`fromip`),
  KEY `incomingid` (`msgid`),
  KEY `fromhost` (`fromhost`),
  KEY `arrival` (`arrival`),
  KEY `subject` (`subject`(767)),
  KEY `prunedsubject` (`prunedsubject`(767)),
  KEY `fromname` (`fromname`),
  KEY `fromuser` (`fromuser`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Message arrivals, used for spam checking' AUTO_INCREMENT=2778685 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_index`
--

CREATE TABLE IF NOT EXISTS `messages_index` (
  `msgid` bigint(20) unsigned NOT NULL,
  `wordid` bigint(20) unsigned NOT NULL,
  `arrival` bigint(20) NOT NULL COMMENT 'We prioritise recent messages',
  `groupid` bigint(20) unsigned DEFAULT NULL,
  UNIQUE KEY `msgid` (`msgid`,`wordid`),
  KEY `arrival` (`arrival`),
  KEY `groupid` (`groupid`),
  KEY `wordid` (`wordid`,`groupid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='For indexing messages for search keywords';

-- --------------------------------------------------------

--
-- Table structure for table `messages_items`
--

CREATE TABLE IF NOT EXISTS `messages_items` (
  `msgid` bigint(20) unsigned NOT NULL,
  `itemid` bigint(20) unsigned NOT NULL,
  UNIQUE KEY `msgid` (`msgid`,`itemid`),
  KEY `itemid` (`itemid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Where known, items for our message';

-- --------------------------------------------------------

--
-- Table structure for table `messages_likes`
--

CREATE TABLE IF NOT EXISTS `messages_likes` (
  `msgid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned NOT NULL,
  `type` enum('Love','Laugh') COLLATE utf8mb4_unicode_ci NOT NULL,
  UNIQUE KEY `msgid_2` (`msgid`,`userid`,`type`),
  KEY `userid` (`userid`),
  KEY `msgid` (`msgid`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `messages_outcomes`
--

CREATE TABLE IF NOT EXISTS `messages_outcomes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `msgid` bigint(20) unsigned NOT NULL,
  `outcome` enum('Taken','Received','Withdrawn','Repost') COLLATE utf8mb4_unicode_ci NOT NULL,
  `happiness` enum('Happy','Fine','Unhappy') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `comments` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`),
  KEY `msgid` (`msgid`),
  KEY `timestamp` (`timestamp`),
  KEY `timestamp_2` (`timestamp`,`outcome`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=832577 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_outcomes_intended`
--

CREATE TABLE IF NOT EXISTS `messages_outcomes_intended` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `msgid` bigint(20) unsigned NOT NULL,
  `outcome` enum('Taken','Received','Withdrawn','Repost') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `msgid_2` (`msgid`,`outcome`),
  KEY `msgid` (`msgid`),
  KEY `timestamp` (`timestamp`),
  KEY `timestamp_2` (`timestamp`,`outcome`),
  KEY `msgid_3` (`msgid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='When someone starts telling us an outcome but doesn''t finish' AUTO_INCREMENT=228416 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_postings`
--

CREATE TABLE IF NOT EXISTS `messages_postings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `msgid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `repost` tinyint(1) NOT NULL DEFAULT '0',
  `autorepost` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `msgid` (`msgid`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1349785 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_promises`
--

CREATE TABLE IF NOT EXISTS `messages_promises` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `msgid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned NOT NULL,
  `promisedat` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `msgid_2` (`msgid`,`userid`),
  KEY `msgid` (`msgid`),
  KEY `userid` (`userid`),
  KEY `promisedat` (`promisedat`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=107933 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_related`
--

CREATE TABLE IF NOT EXISTS `messages_related` (
  `id1` bigint(20) unsigned NOT NULL,
  `id2` bigint(20) unsigned NOT NULL,
  UNIQUE KEY `id1_2` (`id1`,`id2`),
  KEY `id1` (`id1`),
  KEY `id2` (`id2`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Messages which are related to each other';

-- --------------------------------------------------------

--
-- Table structure for table `messages_reneged`
--

CREATE TABLE IF NOT EXISTS `messages_reneged` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `msgid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`),
  KEY `msgid` (`msgid`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=3257 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_spamham`
--

CREATE TABLE IF NOT EXISTS `messages_spamham` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `msgid` bigint(20) unsigned NOT NULL,
  `spamham` enum('Spam','Ham') COLLATE utf8mb4_unicode_ci NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `msgid` (`msgid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='User feedback on messages ' AUTO_INCREMENT=55412 ;

-- --------------------------------------------------------

--
-- Table structure for table `mod_bulkops`
--

CREATE TABLE IF NOT EXISTS `mod_bulkops` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `configid` bigint(20) unsigned DEFAULT NULL,
  `set` enum('Members') COLLATE utf8mb4_unicode_ci NOT NULL,
  `criterion` enum('Bouncing','BouncingFor','WebOnly','All') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `runevery` int(11) NOT NULL DEFAULT '168' COMMENT 'In hours',
  `action` enum('Unbounce','Remove','ToGroup','ToSpecialNotices') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bouncingfor` int(11) NOT NULL DEFAULT '90',
  UNIQUE KEY `uniqueid` (`id`),
  KEY `configid` (`configid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=29447 ;

-- --------------------------------------------------------

--
-- Table structure for table `mod_bulkops_run`
--

CREATE TABLE IF NOT EXISTS `mod_bulkops_run` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `bulkopid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `runstarted` timestamp NULL DEFAULT NULL,
  `runfinished` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `bulkopid_2` (`bulkopid`,`groupid`),
  KEY `bulkopid` (`bulkopid`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=5024231 ;

-- --------------------------------------------------------

--
-- Table structure for table `mod_configs`
--

CREATE TABLE IF NOT EXISTS `mod_configs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID of config',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Name of config set',
  `createdby` bigint(20) unsigned DEFAULT NULL COMMENT 'Moderator ID who created it',
  `fromname` enum('My name','Groupname Moderator') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'My name',
  `ccrejectto` enum('Nobody','Me','Specific') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Nobody',
  `ccrejectaddr` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ccfollowupto` enum('Nobody','Me','Specific') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Nobody',
  `ccfollowupaddr` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ccrejmembto` enum('Nobody','Me','Specific') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Nobody',
  `ccrejmembaddr` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ccfollmembto` enum('Nobody','Me','Specific') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Nobody',
  `ccfollmembaddr` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `protected` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Protect from edit?',
  `messageorder` mediumtext COLLATE utf8mb4_unicode_ci COMMENT 'CSL of ids of standard messages in order in which they should appear',
  `network` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `coloursubj` tinyint(1) NOT NULL DEFAULT '1',
  `subjreg` varchar(1024) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '^(OFFER|WANTED|TAKEN|RECEIVED) *[\\:-].*\\(.*\\)',
  `subjlen` int(11) NOT NULL DEFAULT '68',
  `default` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Default configs are always visible',
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `uniqueid` (`id`,`createdby`),
  KEY `createdby` (`createdby`),
  KEY `default` (`default`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Configurations for use by moderators' AUTO_INCREMENT=63182 ;

-- --------------------------------------------------------

--
-- Table structure for table `mod_stdmsgs`
--

CREATE TABLE IF NOT EXISTS `mod_stdmsgs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID of standard message',
  `configid` bigint(20) unsigned DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Title of standard message',
  `action` enum('Approve','Reject','Leave','Approve Member','Reject Member','Leave Member','Leave Approved Message','Delete Approved Message','Leave Approved Member','Delete Approved Member','Edit') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Reject' COMMENT 'What action to take',
  `subjpref` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Subject prefix',
  `subjsuff` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Subject suffix',
  `body` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `rarelyused` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Rarely used messages may be hidden in the UI',
  `autosend` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Send the message immediately rather than wait for user',
  `newmodstatus` enum('UNCHANGED','MODERATED','DEFAULT','PROHIBITED','UNMODERATED') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'UNCHANGED' COMMENT 'Yahoo mod status afterwards',
  `newdelstatus` enum('UNCHANGED','DIGEST','NONE','SINGLE','ANNOUNCEMENT') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'UNCHANGED' COMMENT 'Yahoo delivery status afterwards',
  `edittext` enum('Unchanged','Correct Case') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Unchanged',
  `insert` enum('Top','Bottom') COLLATE utf8mb4_unicode_ci DEFAULT 'Top',
  UNIQUE KEY `id` (`id`),
  KEY `configid` (`configid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=186926 ;

-- --------------------------------------------------------

--
-- Table structure for table `newsfeed`
--

CREATE TABLE IF NOT EXISTS `newsfeed` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('Message','CommunityEvent','VolunteerOpportunity','CentralPublicity','Alert','Story','ReferToWanted','ReferToOffer','ReferToTaken','ReferToReceived') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Message',
  `userid` bigint(20) unsigned DEFAULT NULL,
  `imageid` bigint(20) unsigned DEFAULT NULL,
  `msgid` bigint(20) unsigned DEFAULT NULL,
  `replyto` bigint(20) unsigned DEFAULT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `eventid` bigint(20) unsigned DEFAULT NULL,
  `volunteeringid` bigint(20) unsigned DEFAULT NULL,
  `publicityid` bigint(20) unsigned DEFAULT NULL,
  `storyid` bigint(20) unsigned DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  `position` point NOT NULL,
  `reviewrequired` tinyint(1) NOT NULL DEFAULT '0',
  `deleted` timestamp NULL DEFAULT NULL,
  `deletedby` bigint(20) unsigned DEFAULT NULL,
  `hidden` timestamp NULL DEFAULT NULL,
  `hiddenby` bigint(20) unsigned DEFAULT NULL,
  `closed` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `eventid` (`eventid`),
  KEY `userid` (`userid`),
  KEY `imageid` (`imageid`),
  KEY `msgid` (`msgid`),
  KEY `replyto` (`replyto`),
  SPATIAL KEY `position` (`position`),
  KEY `groupid` (`groupid`),
  KEY `volunteeringid` (`volunteeringid`),
  KEY `publicityid` (`publicityid`),
  KEY `timestamp` (`timestamp`),
  KEY `storyid` (`storyid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=18488 ;

-- --------------------------------------------------------

--
-- Table structure for table `newsfeed_likes`
--

CREATE TABLE IF NOT EXISTS `newsfeed_likes` (
  `newsfeedid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `newsfeedid_2` (`newsfeedid`,`userid`),
  KEY `newsfeedid` (`newsfeedid`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `newsfeed_reports`
--

CREATE TABLE IF NOT EXISTS `newsfeed_reports` (
  `newsfeedid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `reason` text COLLATE utf8mb4_unicode_ci,
  UNIQUE KEY `newsfeedid_2` (`newsfeedid`,`userid`),
  KEY `newsfeedid` (`newsfeedid`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `newsfeed_unfollow`
--

CREATE TABLE IF NOT EXISTS `newsfeed_unfollow` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `newsfeedid` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid_2` (`userid`,`newsfeedid`),
  KEY `userid` (`userid`),
  KEY `newsfeedid` (`newsfeedid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=881 ;

-- --------------------------------------------------------

--
-- Table structure for table `newsfeed_users`
--

CREATE TABLE IF NOT EXISTS `newsfeed_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `newsfeedid` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid` (`userid`),
  KEY `newsfeedid` (`newsfeedid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=3635878 ;

-- --------------------------------------------------------

--
-- Table structure for table `newsletters`
--

CREATE TABLE IF NOT EXISTS `newsletters` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `subject` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `textbody` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'For people who don''t read HTML',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed` timestamp NULL DEFAULT NULL,
  `uptouser` bigint(20) unsigned DEFAULT NULL COMMENT 'User id we are upto, roughly',
  `type` enum('General','Stories','','') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'General',
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=266 ;

-- --------------------------------------------------------

--
-- Table structure for table `newsletters_articles`
--

CREATE TABLE IF NOT EXISTS `newsletters_articles` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `newsletterid` bigint(20) unsigned NOT NULL,
  `type` enum('Header','Article') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Article',
  `position` int(11) NOT NULL,
  `html` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `photoid` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `mailid` (`newsletterid`),
  KEY `photo` (`photoid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1280 ;

-- --------------------------------------------------------

--
-- Table structure for table `newsletters_images`
--

CREATE TABLE IF NOT EXISTS `newsletters_images` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `articleid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the groups table',
  `contenttype` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `archived` tinyint(4) DEFAULT '0',
  `data` longblob,
  `identification` mediumtext COLLATE utf8mb4_unicode_ci,
  `hash` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `incomingid` (`articleid`),
  KEY `hash` (`hash`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16 COMMENT='Attachments parsed out from messages and resized' AUTO_INCREMENT=158 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_addresses`
--

CREATE TABLE IF NOT EXISTS `paf_addresses` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `postcodeid` bigint(20) unsigned DEFAULT NULL,
  `posttownid` bigint(20) unsigned DEFAULT NULL,
  `dependentlocalityid` bigint(20) unsigned DEFAULT NULL,
  `doubledependentlocalityid` bigint(20) unsigned DEFAULT NULL,
  `thoroughfaredescriptorid` bigint(20) unsigned DEFAULT NULL,
  `dependentthoroughfaredescriptorid` bigint(20) unsigned DEFAULT NULL,
  `buildingnumber` int(11) DEFAULT NULL,
  `buildingnameid` bigint(20) unsigned DEFAULT NULL,
  `subbuildingnameid` bigint(20) unsigned DEFAULT NULL,
  `poboxid` bigint(20) unsigned DEFAULT NULL,
  `departmentnameid` bigint(20) unsigned DEFAULT NULL,
  `organisationnameid` bigint(20) unsigned DEFAULT NULL,
  `udprn` bigint(20) unsigned DEFAULT NULL,
  `postcodetype` char(1) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suorganisationindicator` char(1) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deliverypointsuffix` varchar(2) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `udprn` (`udprn`),
  KEY `postcodeid` (`postcodeid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=120333629 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_buildingname`
--

CREATE TABLE IF NOT EXISTS `paf_buildingname` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `buildingname` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `buildingname` (`buildingname`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=7910 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_departmentname`
--

CREATE TABLE IF NOT EXISTS `paf_departmentname` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `departmentname` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `departmentname` (`departmentname`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=61310 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_dependentlocality`
--

CREATE TABLE IF NOT EXISTS `paf_dependentlocality` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `dependentlocality` varchar(35) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dependentlocality` (`dependentlocality`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=68759 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_dependentthoroughfaredescriptor`
--

CREATE TABLE IF NOT EXISTS `paf_dependentthoroughfaredescriptor` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `dependentthoroughfaredescriptor` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dependentthoroughfaredescriptor` (`dependentthoroughfaredescriptor`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=74177 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_doubledependentlocality`
--

CREATE TABLE IF NOT EXISTS `paf_doubledependentlocality` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `doubledependentlocality` varchar(35) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `doubledependentlocality` (`doubledependentlocality`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=11519 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_organisationname`
--

CREATE TABLE IF NOT EXISTS `paf_organisationname` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `organisationname` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `organisationname` (`organisationname`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=46202 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_pobox`
--

CREATE TABLE IF NOT EXISTS `paf_pobox` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `pobox` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pobox` (`pobox`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=405392 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_posttown`
--

CREATE TABLE IF NOT EXISTS `paf_posttown` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `posttown` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `posttown` (`posttown`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=4414 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_subbuildingname`
--

CREATE TABLE IF NOT EXISTS `paf_subbuildingname` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `subbuildingname` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `subbuildingname` (`subbuildingname`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=4155659 ;

-- --------------------------------------------------------

--
-- Table structure for table `paf_thoroughfaredescriptor`
--

CREATE TABLE IF NOT EXISTS `paf_thoroughfaredescriptor` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `thoroughfaredescriptor` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `thoroughfaredescriptor` (`thoroughfaredescriptor`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1079723 ;

-- --------------------------------------------------------

--
-- Table structure for table `partners_keys`
--

CREATE TABLE IF NOT EXISTS `partners_keys` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `partner` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='For site-to-site integration' AUTO_INCREMENT=26 ;

-- --------------------------------------------------------

--
-- Table structure for table `plugin`
--

CREATE TABLE IF NOT EXISTS `plugin` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `groupid` bigint(20) unsigned NOT NULL,
  `data` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Outstanding work required to be performed by the plugin' AUTO_INCREMENT=4038355 ;

-- --------------------------------------------------------

--
-- Table structure for table `polls`
--

CREATE TABLE IF NOT EXISTS `polls` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `template` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `logintype` enum('Facebook','Google','Yahoo','Native') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=203 ;

-- --------------------------------------------------------

--
-- Table structure for table `polls_users`
--

CREATE TABLE IF NOT EXISTS `polls_users` (
  `pollid` bigint(20) unsigned NOT NULL,
  `userid` bigint(10) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `shown` tinyint(4) DEFAULT '1',
  `response` text COLLATE utf8mb4_unicode_ci,
  UNIQUE KEY `pollid` (`pollid`,`userid`),
  KEY `pollid_2` (`pollid`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `prerender`
--

CREATE TABLE IF NOT EXISTS `prerender` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `url` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `html` longtext COLLATE utf8mb4_unicode_ci,
  `retrieved` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `timeout` int(11) NOT NULL DEFAULT '60' COMMENT 'In minutes',
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `url` (`url`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Saved copies of HTML for logged out view of pages' AUTO_INCREMENT=4625834 ;

-- --------------------------------------------------------

--
-- Table structure for table `schedules`
--

CREATE TABLE IF NOT EXISTS `schedules` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `agreed` timestamp NULL DEFAULT NULL,
  `schedule` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=119 ;

-- --------------------------------------------------------

--
-- Table structure for table `schedules_users`
--

CREATE TABLE IF NOT EXISTS `schedules_users` (
  `userid` bigint(20) unsigned NOT NULL,
  `scheduleid` bigint(20) unsigned NOT NULL,
  UNIQUE KEY `userid_2` (`userid`,`scheduleid`),
  KEY `userid` (`userid`),
  KEY `scheduleid` (`scheduleid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `search_history`
--

CREATE TABLE IF NOT EXISTS `search_history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `term` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `locationid` bigint(20) unsigned DEFAULT NULL,
  `groups` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `date` (`date`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=21762307 ;

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE IF NOT EXISTS `sessions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `series` bigint(20) unsigned NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `lastactive` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `id_3` (`id`,`series`,`token`),
  KEY `date` (`date`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=8192302 ;

-- --------------------------------------------------------

--
-- Table structure for table `shortlinks`
--

CREATE TABLE IF NOT EXISTS `shortlinks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('Group','Other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Other',
  `groupid` bigint(20) unsigned DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `clicks` bigint(20) NOT NULL DEFAULT '0',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`),
  KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=7160 ;

-- --------------------------------------------------------

--
-- Table structure for table `spam_countries`
--

CREATE TABLE IF NOT EXISTS `spam_countries` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `country` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'A country we want to block',
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `country` (`country`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=2 ;

-- --------------------------------------------------------

--
-- Table structure for table `spam_keywords`
--

CREATE TABLE IF NOT EXISTS `spam_keywords` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `word` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `exclude` text COLLATE utf8mb4_unicode_ci,
  `action` enum('Review','Spam') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Review',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Keywords often used by spammers' AUTO_INCREMENT=194 ;

-- --------------------------------------------------------

--
-- Table structure for table `spam_users`
--

CREATE TABLE IF NOT EXISTS `spam_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `byuserid` bigint(20) unsigned DEFAULT NULL,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `collection` enum('Spammer','Whitelisted','PendingAdd','PendingRemove') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Spammer',
  `reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid` (`userid`),
  KEY `byuserid` (`byuserid`),
  KEY `added` (`added`),
  KEY `collection` (`collection`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Users who are spammers or trusted' AUTO_INCREMENT=21674 ;

-- --------------------------------------------------------

--
-- Table structure for table `spam_whitelist_ips`
--

CREATE TABLE IF NOT EXISTS `spam_whitelist_ips` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ip` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `comment` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `ip` (`ip`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Whitelisted IP addresses' AUTO_INCREMENT=3596 ;

-- --------------------------------------------------------

--
-- Table structure for table `spam_whitelist_links`
--

CREATE TABLE IF NOT EXISTS `spam_whitelist_links` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `domain` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `count` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `domain` (`domain`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Whitelisted domains for URLs' AUTO_INCREMENT=93137 ;

-- --------------------------------------------------------

--
-- Table structure for table `spam_whitelist_subjects`
--

CREATE TABLE IF NOT EXISTS `spam_whitelist_subjects` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `comment` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `ip` (`subject`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Whitelisted subjects' AUTO_INCREMENT=14597 ;

-- --------------------------------------------------------

--
-- Table structure for table `stats`
--

CREATE TABLE IF NOT EXISTS `stats` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `date` date NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `type` enum('ApprovedMessageCount','SpamMessageCount','MessageBreakdown','SpamMemberCount','PostMethodBreakdown','YahooDeliveryBreakdown','YahooPostingBreakdown','ApprovedMemberCount','SupportQueries','Happy','Fine','Unhappy','Searches','Activity','Weight') COLLATE utf8mb4_unicode_ci NOT NULL,
  `count` bigint(20) unsigned DEFAULT NULL,
  `breakdown` mediumtext COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  UNIQUE KEY `date` (`date`,`type`,`groupid`),
  KEY `groupid` (`groupid`),
  KEY `type` (`type`,`date`,`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Stats information used for dashboard' AUTO_INCREMENT=31574450 ;

-- --------------------------------------------------------

--
-- Table structure for table `streetwhacks`
--

CREATE TABLE IF NOT EXISTS `streetwhacks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `locationid` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `count` int(11) NOT NULL DEFAULT '0',
  `streetname` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `sessionid` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=2297 ;

-- --------------------------------------------------------

--
-- Table structure for table `supporters`
--

CREATE TABLE IF NOT EXISTS `supporters` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` enum('Wowzer','Front Page','Supporter','Buyer') COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `display` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `voucher` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Voucher code',
  `vouchercount` int(11) NOT NULL DEFAULT '1' COMMENT 'Number of licenses in this voucher',
  `voucheryears` int(11) NOT NULL DEFAULT '1' COMMENT 'Number of years voucher licenses are valid for',
  `anonymous` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `id` (`id`),
  KEY `name` (`name`,`type`,`email`),
  KEY `display` (`display`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='People who have supported this site' AUTO_INCREMENT=133569 ;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `yahooUserId` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Unique ID of user on Yahoo if known',
  `firstname` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lastname` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fullname` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `systemrole` set('User','Moderator','Support','Admin') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'User' COMMENT 'System-wide roles',
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastaccess` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `settings` mediumtext COLLATE utf8mb4_unicode_ci COMMENT 'JSON-encoded settings',
  `gotrealemail` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'Until migrated, whether polled FD/TN to get real email',
  `suspectcount` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'Number of reports of this user as suspicious',
  `suspectreason` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Last reason for suspecting this user',
  `yahooid` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Any known YahooID for this user',
  `licenses` int(11) NOT NULL DEFAULT '0' COMMENT 'Any licenses not added to groups',
  `newslettersallowed` tinyint(4) NOT NULL DEFAULT '1' COMMENT 'Central mails',
  `relevantallowed` tinyint(4) NOT NULL DEFAULT '1',
  `onholidaytill` date DEFAULT NULL,
  `ripaconsent` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether we have consent for humans to vet their messages',
  `publishconsent` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'Can we republish posts to non-members?',
  `lastlocation` bigint(20) unsigned DEFAULT NULL,
  `lastrelevantcheck` timestamp NULL DEFAULT NULL,
  `lastidlechaseup` timestamp NULL DEFAULT NULL,
  `bouncing` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether preferred email has been determined to be bouncing',
  `permissions` set('BusinessCardsAdmin','Newsletter','NationalVolunteers') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invitesleft` int(10) unsigned DEFAULT '10',
  `source` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `yahooUserId` (`yahooUserId`),
  UNIQUE KEY `yahooid` (`yahooid`),
  KEY `systemrole` (`systemrole`),
  KEY `added` (`added`,`lastaccess`),
  KEY `fullname` (`fullname`),
  KEY `firstname` (`firstname`),
  KEY `lastname` (`lastname`),
  KEY `firstname_2` (`firstname`,`lastname`),
  KEY `gotrealemail` (`gotrealemail`),
  KEY `suspectcount` (`suspectcount`),
  KEY `suspectcount_2` (`suspectcount`),
  KEY `lastlocation` (`lastlocation`),
  KEY `lastrelevantcheck` (`lastrelevantcheck`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=34736380 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_addresses`
--

CREATE TABLE IF NOT EXISTS `users_addresses` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `pafid` bigint(20) unsigned DEFAULT NULL,
  `to` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `instructions` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid_2` (`userid`,`pafid`),
  KEY `userid` (`userid`),
  KEY `pafid` (`pafid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=9299 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_banned`
--

CREATE TABLE IF NOT EXISTS `users_banned` (
  `userid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `byuser` bigint(20) unsigned DEFAULT NULL,
  UNIQUE KEY `userid_2` (`userid`,`groupid`),
  KEY `groupid` (`groupid`),
  KEY `userid` (`userid`),
  KEY `date` (`date`),
  KEY `byuser` (`byuser`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `users_comments`
--

CREATE TABLE IF NOT EXISTS `users_comments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `byuserid` bigint(20) unsigned DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user1` mediumtext COLLATE utf8mb4_unicode_ci,
  `user2` mediumtext COLLATE utf8mb4_unicode_ci,
  `user3` mediumtext COLLATE utf8mb4_unicode_ci,
  `user4` mediumtext COLLATE utf8mb4_unicode_ci,
  `user5` mediumtext COLLATE utf8mb4_unicode_ci,
  `user6` mediumtext COLLATE utf8mb4_unicode_ci,
  `user7` mediumtext COLLATE utf8mb4_unicode_ci,
  `user8` mediumtext COLLATE utf8mb4_unicode_ci,
  `user9` mediumtext COLLATE utf8mb4_unicode_ci,
  `user10` mediumtext COLLATE utf8mb4_unicode_ci,
  `user11` mediumtext COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `groupid` (`groupid`),
  KEY `modid` (`byuserid`),
  KEY `userid` (`userid`,`groupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Comments from mods on members' AUTO_INCREMENT=137801 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_donations`
--

CREATE TABLE IF NOT EXISTS `users_donations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('PayPal','External') COLLATE utf8mb4_unicode_ci NOT NULL,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `Payer` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `PayerDisplayName` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `TransactionID` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `GrossAmount` decimal(10,2) NOT NULL,
  `source` enum('DonateWithPayPal','PayPalGivingFund') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DonateWithPayPal',
  PRIMARY KEY (`id`),
  UNIQUE KEY `TransactionID` (`TransactionID`),
  KEY `userid` (`userid`),
  KEY `GrossAmount` (`GrossAmount`),
  KEY `timestamp` (`timestamp`,`GrossAmount`),
  KEY `timestamp_2` (`timestamp`,`userid`,`GrossAmount`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1313947 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_donations_asks`
--

CREATE TABLE IF NOT EXISTS `users_donations_asks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=14 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_emails`
--

CREATE TABLE IF NOT EXISTS `users_emails` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL COMMENT 'Unique ID in users table',
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'The email',
  `preferred` tinyint(4) NOT NULL DEFAULT '1' COMMENT 'Preferred email for this user',
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `validatekey` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `validated` timestamp NULL DEFAULT NULL,
  `canon` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'For spotting duplicates',
  `backwards` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Allows domain search',
  `bounced` timestamp NULL DEFAULT NULL,
  `viewed` timestamp NULL DEFAULT NULL,
  `md5hash` varchar(32) COLLATE utf8mb4_unicode_ci GENERATED ALWAYS AS (md5(lower(`email`))) VIRTUAL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `validatekey` (`validatekey`),
  KEY `userid` (`userid`),
  KEY `validated` (`validated`),
  KEY `canon` (`canon`),
  KEY `backwards` (`backwards`),
  KEY `bounced` (`bounced`),
  KEY `viewed` (`viewed`),
  KEY `md5hash` (`md5hash`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=118397611 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_images`
--

CREATE TABLE IF NOT EXISTS `users_images` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL COMMENT 'id in the users table',
  `contenttype` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `default` tinyint(1) NOT NULL DEFAULT '0',
  `url` varchar(1024) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `archived` tinyint(4) DEFAULT '0',
  `data` longblob,
  `identification` mediumtext COLLATE utf8mb4_unicode_ci,
  `hash` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `incomingid` (`userid`),
  KEY `hash` (`hash`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16 COMMENT='Attachments parsed out from messages and resized' AUTO_INCREMENT=2926871 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_invitations`
--

CREATE TABLE IF NOT EXISTS `users_invitations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `outcome` enum('Pending','Accepted','Declined','') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Pending',
  `outcometimestamp` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid_2` (`userid`,`email`),
  KEY `userid` (`userid`),
  KEY `email` (`email`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=6824 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_logins`
--

CREATE TABLE IF NOT EXISTS `users_logins` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL COMMENT 'Unique ID in users table',
  `type` enum('Yahoo','Facebook','Google','Native','Link') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uid` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Unique identifier for login',
  `credentials` text COLLATE utf8mb4_unicode_ci,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastaccess` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `credentials2` text COLLATE utf8mb4_unicode_ci COMMENT 'For Link logins',
  `credentialsrotated` timestamp NULL DEFAULT NULL COMMENT 'For Link logins',
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`uid`,`type`),
  UNIQUE KEY `userid_3` (`userid`,`type`,`uid`),
  KEY `userid` (`userid`),
  KEY `validated` (`lastaccess`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC AUTO_INCREMENT=6821678 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_nearby`
--

CREATE TABLE IF NOT EXISTS `users_nearby` (
  `userid` bigint(20) unsigned NOT NULL,
  `msgid` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `userid_2` (`userid`,`msgid`),
  KEY `userid` (`userid`),
  KEY `msgid` (`msgid`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users_notifications`
--

CREATE TABLE IF NOT EXISTS `users_notifications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `fromuser` bigint(20) unsigned DEFAULT NULL,
  `touser` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('CommentOnYourPost','CommentOnCommented','LovedPost','LovedComment','TryFeed') COLLATE utf8mb4_unicode_ci NOT NULL,
  `newsfeedid` bigint(20) unsigned DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `seen` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `newsfeedid` (`newsfeedid`),
  KEY `touser` (`touser`),
  KEY `fromuser` (`fromuser`),
  KEY `userid` (`touser`,`id`,`seen`),
  KEY `touser_2` (`timestamp`,`seen`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1636889 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_nudges`
--

CREATE TABLE IF NOT EXISTS `users_nudges` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `fromuser` bigint(20) unsigned NOT NULL,
  `touser` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `responded` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fromuser` (`fromuser`),
  KEY `touser` (`touser`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=11594 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_phones`
--

CREATE TABLE IF NOT EXISTS `users_phones` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `number` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_push_notifications`
--

CREATE TABLE IF NOT EXISTS `users_push_notifications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('Google','Firefox','Test','Android','IOS') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Google',
  `lastsent` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `subscription` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `apptype` enum('User','ModTools') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'User',
  PRIMARY KEY (`id`),
  UNIQUE KEY `subscription` (`subscription`),
  KEY `userid` (`userid`,`type`),
  KEY `type` (`type`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='For sending push notifications to users' AUTO_INCREMENT=3248668 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_requests`
--

CREATE TABLE IF NOT EXISTS `users_requests` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `type` enum('BusinessCards') COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed` timestamp NULL DEFAULT NULL,
  `completedby` bigint(20) unsigned DEFAULT NULL,
  `addressid` bigint(20) unsigned DEFAULT NULL,
  `to` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notifiedmods` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `addressid` (`addressid`),
  KEY `userid` (`userid`),
  KEY `completedby` (`completedby`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=3530 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_searches`
--

CREATE TABLE IF NOT EXISTS `users_searches` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `term` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `maxmsg` bigint(20) unsigned DEFAULT NULL,
  `deleted` tinyint(4) NOT NULL DEFAULT '0',
  `locationid` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid` (`userid`,`term`),
  KEY `locationid` (`locationid`),
  KEY `userid_2` (`userid`),
  KEY `maxmsg` (`maxmsg`),
  KEY `userid_3` (`userid`,`date`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=11636085 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_stories`
--

CREATE TABLE IF NOT EXISTS `users_stories` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `public` tinyint(1) NOT NULL DEFAULT '1',
  `reviewed` tinyint(1) NOT NULL DEFAULT '0',
  `headline` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `story` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `tweeted` tinyint(4) NOT NULL DEFAULT '0',
  `mailedtocentral` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Mailed to groups mailing list',
  `mailedtomembers` tinyint(1) DEFAULT '0',
  `newsletterreviewed` tinyint(1) NOT NULL DEFAULT '0',
  `newsletter` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`),
  KEY `date` (`date`),
  KEY `reviewed` (`reviewed`,`public`,`newsletterreviewed`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=2771 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_stories_likes`
--

CREATE TABLE IF NOT EXISTS `users_stories_likes` (
  `storyid` bigint(20) unsigned NOT NULL,
  `userid` bigint(20) unsigned NOT NULL,
  UNIQUE KEY `storyid_2` (`storyid`,`userid`),
  KEY `storyid` (`storyid`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users_stories_requested`
--

CREATE TABLE IF NOT EXISTS `users_stories_requested` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=85088 ;

-- --------------------------------------------------------

--
-- Table structure for table `users_thanks`
--

CREATE TABLE IF NOT EXISTS `users_thanks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=7682 ;

-- --------------------------------------------------------

--
-- Table structure for table `volunteering`
--

CREATE TABLE IF NOT EXISTS `volunteering` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userid` bigint(20) unsigned DEFAULT NULL,
  `pending` tinyint(1) NOT NULL DEFAULT '0',
  `title` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `online` tinyint(1) NOT NULL DEFAULT '0',
  `location` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `contactname` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contactphone` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contactemail` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contacturl` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` tinyint(4) NOT NULL DEFAULT '0',
  `askedtorenew` timestamp NULL DEFAULT NULL,
  `renewed` timestamp NULL DEFAULT NULL,
  `expired` tinyint(1) NOT NULL DEFAULT '0',
  `timecommitment` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `userid` (`userid`),
  KEY `title` (`title`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=3317 ;

-- --------------------------------------------------------

--
-- Table structure for table `volunteering_dates`
--

CREATE TABLE IF NOT EXISTS `volunteering_dates` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `volunteeringid` bigint(20) unsigned NOT NULL,
  `start` timestamp NULL DEFAULT NULL,
  `end` timestamp NULL DEFAULT NULL,
  `applyby` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `start` (`start`),
  KEY `eventid` (`volunteeringid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1274 ;

-- --------------------------------------------------------

--
-- Table structure for table `volunteering_groups`
--

CREATE TABLE IF NOT EXISTS `volunteering_groups` (
  `volunteeringid` bigint(20) unsigned NOT NULL,
  `groupid` bigint(20) unsigned NOT NULL,
  `arrival` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `eventid_2` (`volunteeringid`,`groupid`),
  KEY `eventid` (`volunteeringid`),
  KEY `groupid` (`groupid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `vouchers`
--

CREATE TABLE IF NOT EXISTS `vouchers` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `voucher` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `used` timestamp NULL DEFAULT NULL,
  `groupid` bigint(20) unsigned DEFAULT NULL COMMENT 'Group that a voucher was used on',
  `userid` bigint(20) unsigned DEFAULT NULL COMMENT 'User who redeemed a voucher',
  PRIMARY KEY (`id`),
  UNIQUE KEY `voucher` (`voucher`),
  KEY `groupid` (`groupid`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='For licensing groups' AUTO_INCREMENT=3632 ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_donations`
--
CREATE TABLE IF NOT EXISTS `vw_donations` (
   `total` decimal(32,2)
  ,`date` date
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_ECC`
--
CREATE TABLE IF NOT EXISTS `vw_ECC` (
   `date` timestamp
  ,`count` bigint(21)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `VW_Essex_Searches`
--
CREATE TABLE IF NOT EXISTS `VW_Essex_Searches` (
   `DATE` date
  ,`count` bigint(21)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_freeglegroups_unreached`
--
CREATE TABLE IF NOT EXISTS `vw_freeglegroups_unreached` (
   `id` bigint(20) unsigned
  ,`nameshort` varchar(80)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_manyemails`
--
CREATE TABLE IF NOT EXISTS `vw_manyemails` (
   `id` bigint(20) unsigned
  ,`fullname` varchar(255)
  ,`email` varchar(255)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_membersyncpending`
--
CREATE TABLE IF NOT EXISTS `vw_membersyncpending` (
   `id` bigint(20) unsigned
  ,`groupid` bigint(20) unsigned
  ,`members` longtext
  ,`lastupdated` timestamp
  ,`lastprocessed` timestamp
  ,`synctime` timestamp
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_multiemails`
--
CREATE TABLE IF NOT EXISTS `vw_multiemails` (
   `id` bigint(20) unsigned
  ,`fullname` varchar(255)
  ,`count` bigint(21)
  ,`GROUP_CONCAT(email SEPARATOR ', ')` text
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_recentgroupaccess`
--
CREATE TABLE IF NOT EXISTS `vw_recentgroupaccess` (
   `lastaccess` timestamp
  ,`nameshort` varchar(80)
  ,`id` bigint(20) unsigned
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_recentlogins`
--
CREATE TABLE IF NOT EXISTS `vw_recentlogins` (
   `timestamp` timestamp
  ,`id` bigint(20) unsigned
  ,`fullname` varchar(255)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_recentposts`
--
CREATE TABLE IF NOT EXISTS `vw_recentposts` (
   `id` bigint(20) unsigned
  ,`date` timestamp
  ,`fromaddr` varchar(255)
  ,`subject` varchar(255)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `VW_recentqueries`
--
CREATE TABLE IF NOT EXISTS `VW_recentqueries` (
   `id` bigint(20) unsigned
  ,`chatid` bigint(20) unsigned
  ,`userid` bigint(20) unsigned
  ,`type` enum('Default','System','ModMail','Interested','Promised','Reneged','ReportedUser','Completed','Image','Address','Nudge','Schedule','ScheduleUpdated')
  ,`reportreason` enum('Spam','Other')
  ,`refmsgid` bigint(20) unsigned
  ,`refchatid` bigint(20) unsigned
  ,`date` timestamp
  ,`message` text
  ,`platform` tinyint(4)
  ,`seenbyall` tinyint(1)
  ,`reviewrequired` tinyint(1)
  ,`reviewedby` bigint(20) unsigned
  ,`reviewrejected` tinyint(1)
  ,`spamscore` int(11)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `VW_routes`
--
CREATE TABLE IF NOT EXISTS `VW_routes` (
   `route` varchar(255)
  ,`count` bigint(21)
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_src`
--
CREATE TABLE IF NOT EXISTS `vw_src` (
   `count` bigint(21)
  ,`src` varchar(40)
);
-- --------------------------------------------------------

--
-- Table structure for table `weights`
--

CREATE TABLE IF NOT EXISTS `weights` (
  `name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `simplename` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'The name in simpler terms',
  `weight` decimal(5,2) NOT NULL,
  `source` enum('FRN 2009','Freegle') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'FRN 2009',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Standard weights, from FRN 2009';

-- --------------------------------------------------------

--
-- Table structure for table `words`
--

CREATE TABLE IF NOT EXISTS `words` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `word` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `firstthree` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL,
  `soundex` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `popularity` bigint(20) NOT NULL DEFAULT '0' COMMENT 'Negative as DESC index not supported',
  PRIMARY KEY (`id`),
  UNIQUE KEY `word_2` (`word`),
  KEY `popularity` (`popularity`),
  KEY `word` (`word`,`popularity`),
  KEY `soundex` (`soundex`,`popularity`),
  KEY `firstthree` (`firstthree`,`popularity`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='Unique words for searches' AUTO_INCREMENT=8580856 ;

-- --------------------------------------------------------

--
-- Structure for view `vw_donations`
--
DROP TABLE IF EXISTS `vw_donations`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_donations` AS select sum(`users_donations`.`GrossAmount`) AS `total`,cast(`users_donations`.`timestamp` as date) AS `date` from `users_donations` where (((to_days(now()) - to_days(`users_donations`.`timestamp`)) < 31) and (`users_donations`.`Payer` <> 'ppgfukpay@paypalgivingfund.org')) group by `date` order by `date` desc;

-- --------------------------------------------------------

--
-- Structure for view `vw_ECC`
--
DROP TABLE IF EXISTS `vw_ECC`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_ECC` AS select `logs_src`.`date` AS `date`,count(0) AS `count` from `logs_src` where (`logs_src`.`src` = 'ECC') group by cast(`logs_src`.`date` as date) order by `logs_src`.`date`;

-- --------------------------------------------------------

--
-- Structure for view `VW_Essex_Searches`
--
DROP TABLE IF EXISTS `VW_Essex_Searches`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `VW_Essex_Searches` AS select cast(`users_searches`.`date` as date) AS `DATE`,count(0) AS `count` from (`users_searches` join `locations` on((`users_searches`.`locationid` = `locations`.`id`))) where (mbrwithin(`locations`.`geometry`,(select `authorities`.`polygon` from `authorities` where (`authorities`.`name` like '%essex%'))) and (`users_searches`.`date` > '2017-07-01')) group by cast(`users_searches`.`date` as date) order by `DATE`;

-- --------------------------------------------------------

--
-- Structure for view `vw_freeglegroups_unreached`
--
DROP TABLE IF EXISTS `vw_freeglegroups_unreached`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_freeglegroups_unreached` AS select `groups`.`id` AS `id`,`groups`.`nameshort` AS `nameshort` from `groups` where ((`groups`.`type` = 'Freegle') and (not((`groups`.`nameshort` like '%playground%'))) and (not((`groups`.`nameshort` like '%test%'))) and (not(`groups`.`id` in (select `alerts_tracking`.`groupid` from `alerts_tracking` where (`alerts_tracking`.`response` is not null))))) order by `groups`.`nameshort`;

-- --------------------------------------------------------

--
-- Structure for view `vw_manyemails`
--
DROP TABLE IF EXISTS `vw_manyemails`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_manyemails` AS select `users`.`id` AS `id`,`users`.`fullname` AS `fullname`,`users_emails`.`email` AS `email` from (`users` join `users_emails` on((`users`.`id` = `users_emails`.`userid`))) where `users`.`id` in (select `users_emails`.`userid` from `users_emails` group by `users_emails`.`userid` having (count(0) > 4) order by count(0) desc);

-- --------------------------------------------------------

--
-- Structure for view `vw_membersyncpending`
--
DROP TABLE IF EXISTS `vw_membersyncpending`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_membersyncpending` AS select `memberships_yahoo_dump`.`id` AS `id`,`memberships_yahoo_dump`.`groupid` AS `groupid`,`memberships_yahoo_dump`.`members` AS `members`,`memberships_yahoo_dump`.`lastupdated` AS `lastupdated`,`memberships_yahoo_dump`.`lastprocessed` AS `lastprocessed`,`memberships_yahoo_dump`.`synctime` AS `synctime` from `memberships_yahoo_dump` where (isnull(`memberships_yahoo_dump`.`lastprocessed`) or (`memberships_yahoo_dump`.`lastupdated` > `memberships_yahoo_dump`.`lastprocessed`));

-- --------------------------------------------------------

--
-- Structure for view `vw_multiemails`
--
DROP TABLE IF EXISTS `vw_multiemails`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_multiemails` AS select `vw_manyemails`.`id` AS `id`,`vw_manyemails`.`fullname` AS `fullname`,count(0) AS `count`,group_concat(`vw_manyemails`.`email` separator ', ') AS `GROUP_CONCAT(email SEPARATOR ', ')` from `vw_manyemails` group by `vw_manyemails`.`id` order by `count` desc;

-- --------------------------------------------------------

--
-- Structure for view `vw_recentgroupaccess`
--
DROP TABLE IF EXISTS `vw_recentgroupaccess`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_recentgroupaccess` AS select `users_logins`.`lastaccess` AS `lastaccess`,`groups`.`nameshort` AS `nameshort`,`groups`.`id` AS `id` from ((`users_logins` join `memberships` on(((`users_logins`.`userid` = `memberships`.`userid`) and (`memberships`.`role` in ('Owner','Moderator'))))) join `groups` on((`memberships`.`groupid` = `groups`.`id`))) order by `users_logins`.`lastaccess` desc;

-- --------------------------------------------------------

--
-- Structure for view `vw_recentlogins`
--
DROP TABLE IF EXISTS `vw_recentlogins`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_recentlogins` AS select `logs`.`timestamp` AS `timestamp`,`users`.`id` AS `id`,`users`.`fullname` AS `fullname` from (`users` join `logs` on((`users`.`id` = `logs`.`byuser`))) where ((`logs`.`type` = 'User') and (`logs`.`subtype` = 'Login')) order by `logs`.`timestamp` desc;

-- --------------------------------------------------------

--
-- Structure for view `vw_recentposts`
--
DROP TABLE IF EXISTS `vw_recentposts`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_recentposts` AS select `messages`.`id` AS `id`,`messages`.`date` AS `date`,`messages`.`fromaddr` AS `fromaddr`,`messages`.`subject` AS `subject` from (`messages` left join `messages_drafts` on((`messages_drafts`.`msgid` = `messages`.`id`))) where ((`messages`.`source` = 'Platform') and isnull(`messages_drafts`.`msgid`)) order by `messages`.`date` desc limit 20;

-- --------------------------------------------------------

--
-- Structure for view `VW_recentqueries`
--
DROP TABLE IF EXISTS `VW_recentqueries`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `VW_recentqueries` AS select `chat_messages`.`id` AS `id`,`chat_messages`.`chatid` AS `chatid`,`chat_messages`.`userid` AS `userid`,`chat_messages`.`type` AS `type`,`chat_messages`.`reportreason` AS `reportreason`,`chat_messages`.`refmsgid` AS `refmsgid`,`chat_messages`.`refchatid` AS `refchatid`,`chat_messages`.`date` AS `date`,`chat_messages`.`message` AS `message`,`chat_messages`.`platform` AS `platform`,`chat_messages`.`seenbyall` AS `seenbyall`,`chat_messages`.`reviewrequired` AS `reviewrequired`,`chat_messages`.`reviewedby` AS `reviewedby`,`chat_messages`.`reviewrejected` AS `reviewrejected`,`chat_messages`.`spamscore` AS `spamscore` from (`chat_messages` join `chat_rooms` on((`chat_messages`.`chatid` = `chat_rooms`.`id`))) where (`chat_rooms`.`chattype` = 'User2Mod') order by `chat_messages`.`date` desc;

-- --------------------------------------------------------

--
-- Structure for view `VW_routes`
--
DROP TABLE IF EXISTS `VW_routes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `VW_routes` AS select `logs_events`.`route` AS `route`,count(0) AS `count` from `logs_events` group by `logs_events`.`route` order by `count` desc;

-- --------------------------------------------------------

--
-- Structure for view `vw_src`
--
DROP TABLE IF EXISTS `vw_src`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_src` AS select count(0) AS `count`,`logs_src`.`src` AS `src` from `logs_src` group by `logs_src`.`src` order by `count` desc;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `alerts`
--
ALTER TABLE `alerts`
  ADD CONSTRAINT `alerts_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `alerts_ibfk_2` FOREIGN KEY (`createdby`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `alerts_tracking`
--
ALTER TABLE `alerts_tracking`
  ADD CONSTRAINT `_alerts_tracking_ibfk_3` FOREIGN KEY (`emailid`) REFERENCES `users_emails` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `alerts_tracking_ibfk_1` FOREIGN KEY (`alertid`) REFERENCES `alerts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `alerts_tracking_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `alerts_tracking_ibfk_4` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `bounces_emails`
--
ALTER TABLE `bounces_emails`
  ADD CONSTRAINT `bounces_emails_ibfk_1` FOREIGN KEY (`emailid`) REFERENCES `users_emails` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `chat_images`
--
ALTER TABLE `chat_images`
  ADD CONSTRAINT `_chat_images_ibfk_1` FOREIGN KEY (`chatmsgid`) REFERENCES `chat_messages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `chat_messages`
--
ALTER TABLE `chat_messages`
  ADD CONSTRAINT `_chat_messages_ibfk_1` FOREIGN KEY (`chatid`) REFERENCES `chat_rooms` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `_chat_messages_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `_chat_messages_ibfk_3` FOREIGN KEY (`refmsgid`) REFERENCES `messages` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `_chat_messages_ibfk_4` FOREIGN KEY (`reviewedby`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `_chat_messages_ibfk_5` FOREIGN KEY (`refchatid`) REFERENCES `chat_rooms` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `chat_messages_ibfk_1` FOREIGN KEY (`imageid`) REFERENCES `chat_images` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `chat_messages_ibfk_2` FOREIGN KEY (`scheduleid`) REFERENCES `schedules` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `chat_rooms`
--
ALTER TABLE `chat_rooms`
  ADD CONSTRAINT `chat_rooms_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `chat_rooms_ibfk_2` FOREIGN KEY (`user1`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `chat_rooms_ibfk_3` FOREIGN KEY (`user2`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `chat_roster`
--
ALTER TABLE `chat_roster`
  ADD CONSTRAINT `chat_roster_ibfk_1` FOREIGN KEY (`chatid`) REFERENCES `chat_rooms` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `chat_roster_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `communityevents`
--
ALTER TABLE `communityevents`
  ADD CONSTRAINT `communityevents_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `communityevents_dates`
--
ALTER TABLE `communityevents_dates`
  ADD CONSTRAINT `communityevents_dates_ibfk_1` FOREIGN KEY (`eventid`) REFERENCES `communityevents` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `communityevents_groups`
--
ALTER TABLE `communityevents_groups`
  ADD CONSTRAINT `communityevents_groups_ibfk_1` FOREIGN KEY (`eventid`) REFERENCES `communityevents` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `communityevents_groups_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `communityevents_images`
--
ALTER TABLE `communityevents_images`
  ADD CONSTRAINT `communityevents_images_ibfk_1` FOREIGN KEY (`eventid`) REFERENCES `communityevents` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `groups`
--
ALTER TABLE `groups`
  ADD CONSTRAINT `groups_ibfk_1` FOREIGN KEY (`profile`) REFERENCES `groups_images` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `groups_ibfk_2` FOREIGN KEY (`cover`) REFERENCES `groups` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `groups_ibfk_3` FOREIGN KEY (`authorityid`) REFERENCES `authorities` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `groups_digests`
--
ALTER TABLE `groups_digests`
  ADD CONSTRAINT `groups_digests_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `groups_digests_ibfk_3` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `groups_facebook`
--
ALTER TABLE `groups_facebook`
  ADD CONSTRAINT `groups_facebook_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `groups_facebook_shares`
--
ALTER TABLE `groups_facebook_shares`
  ADD CONSTRAINT `groups_facebook_shares_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `groups_facebook_shares_ibfk_2` FOREIGN KEY (`uid`) REFERENCES `groups_facebook` (`uid`) ON DELETE CASCADE;

--
-- Constraints for table `groups_images`
--
ALTER TABLE `groups_images`
  ADD CONSTRAINT `groups_images_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `groups_twitter`
--
ALTER TABLE `groups_twitter`
  ADD CONSTRAINT `groups_twitter_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `groups_twitter_ibfk_2` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `groups_twitter_ibfk_3` FOREIGN KEY (`eventid`) REFERENCES `communityevents` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `items_index`
--
ALTER TABLE `items_index`
  ADD CONSTRAINT `items_index_ibfk_1` FOREIGN KEY (`itemid`) REFERENCES `items` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `items_index_ibfk_2` FOREIGN KEY (`wordid`) REFERENCES `words` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `locations`
--
ALTER TABLE `locations`
  ADD CONSTRAINT `locations_ibfk_1` FOREIGN KEY (`gridid`) REFERENCES `locations_grids` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `locations_excluded`
--
ALTER TABLE `locations_excluded`
  ADD CONSTRAINT `_locations_excluded_ibfk_1` FOREIGN KEY (`locationid`) REFERENCES `locations` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `locations_excluded_ibfk_3` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `locations_excluded_ibfk_4` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `locations_grids_touches`
--
ALTER TABLE `locations_grids_touches`
  ADD CONSTRAINT `locations_grids_touches_ibfk_1` FOREIGN KEY (`gridid`) REFERENCES `locations_grids` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `locations_grids_touches_ibfk_2` FOREIGN KEY (`touches`) REFERENCES `locations_grids` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `locations_spatial`
--
ALTER TABLE `locations_spatial`
  ADD CONSTRAINT `locations_spatial_ibfk_1` FOREIGN KEY (`locationid`) REFERENCES `locations` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `logs_emails`
--
ALTER TABLE `logs_emails`
  ADD CONSTRAINT `logs_emails_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `memberships`
--
ALTER TABLE `memberships`
  ADD CONSTRAINT `memberships_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `memberships_ibfk_3` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `memberships_ibfk_4` FOREIGN KEY (`heldby`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `memberships_ibfk_5` FOREIGN KEY (`configid`) REFERENCES `mod_configs` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `memberships_history`
--
ALTER TABLE `memberships_history`
  ADD CONSTRAINT `memberships_history_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `memberships_history_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `memberships_yahoo`
--
ALTER TABLE `memberships_yahoo`
  ADD CONSTRAINT `_memberships_yahoo_ibfk_1` FOREIGN KEY (`membershipid`) REFERENCES `memberships` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `memberships_yahoo_ibfk_1` FOREIGN KEY (`emailid`) REFERENCES `users_emails` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `memberships_yahoo_dump`
--
ALTER TABLE `memberships_yahoo_dump`
  ADD CONSTRAINT `memberships_yahoo_dump_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages`
--
ALTER TABLE `messages`
  ADD CONSTRAINT `_messages_ibfk_1` FOREIGN KEY (`heldby`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `_messages_ibfk_2` FOREIGN KEY (`fromuser`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `_messages_ibfk_3` FOREIGN KEY (`locationid`) REFERENCES `locations` (`id`) ON DELETE SET NULL ON UPDATE NO ACTION;

--
-- Constraints for table `messages_attachments`
--
ALTER TABLE `messages_attachments`
  ADD CONSTRAINT `_messages_attachments_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_attachments_items`
--
ALTER TABLE `messages_attachments_items`
  ADD CONSTRAINT `messages_attachments_items_ibfk_1` FOREIGN KEY (`attid`) REFERENCES `messages_attachments` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_attachments_items_ibfk_2` FOREIGN KEY (`itemid`) REFERENCES `items` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_drafts`
--
ALTER TABLE `messages_drafts`
  ADD CONSTRAINT `messages_drafts_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_drafts_ibfk_2` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_drafts_ibfk_3` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `messages_groups`
--
ALTER TABLE `messages_groups`
  ADD CONSTRAINT `_messages_groups_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `_messages_groups_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `_messages_groups_ibfk_3` FOREIGN KEY (`approvedby`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `messages_history`
--
ALTER TABLE `messages_history`
  ADD CONSTRAINT `_messages_history_ibfk_1` FOREIGN KEY (`fromuser`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `_messages_history_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_index`
--
ALTER TABLE `messages_index`
  ADD CONSTRAINT `_messages_index_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `_messages_index_ibfk_3` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `messages_index_ibfk_1` FOREIGN KEY (`wordid`) REFERENCES `words` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_items`
--
ALTER TABLE `messages_items`
  ADD CONSTRAINT `messages_items_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_items_ibfk_2` FOREIGN KEY (`itemid`) REFERENCES `items` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_likes`
--
ALTER TABLE `messages_likes`
  ADD CONSTRAINT `messages_likes_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_likes_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_outcomes`
--
ALTER TABLE `messages_outcomes`
  ADD CONSTRAINT `messages_outcomes_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_outcomes_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `messages_outcomes_intended`
--
ALTER TABLE `messages_outcomes_intended`
  ADD CONSTRAINT `messages_outcomes_intended_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_postings`
--
ALTER TABLE `messages_postings`
  ADD CONSTRAINT `messages_postings_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_postings_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_promises`
--
ALTER TABLE `messages_promises`
  ADD CONSTRAINT `messages_promises_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_promises_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_related`
--
ALTER TABLE `messages_related`
  ADD CONSTRAINT `messages_related_ibfk_1` FOREIGN KEY (`id1`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_related_ibfk_2` FOREIGN KEY (`id2`) REFERENCES `messages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_reneged`
--
ALTER TABLE `messages_reneged`
  ADD CONSTRAINT `messages_reneged_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `messages_reneged_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `messages_spamham`
--
ALTER TABLE `messages_spamham`
  ADD CONSTRAINT `messages_spamham_ibfk_1` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `mod_bulkops`
--
ALTER TABLE `mod_bulkops`
  ADD CONSTRAINT `mod_bulkops_ibfk_1` FOREIGN KEY (`configid`) REFERENCES `mod_configs` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `mod_bulkops_run`
--
ALTER TABLE `mod_bulkops_run`
  ADD CONSTRAINT `mod_bulkops_run_ibfk_1` FOREIGN KEY (`bulkopid`) REFERENCES `mod_bulkops` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `mod_bulkops_run_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `mod_configs`
--
ALTER TABLE `mod_configs`
  ADD CONSTRAINT `mod_configs_ibfk_1` FOREIGN KEY (`createdby`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `mod_stdmsgs`
--
ALTER TABLE `mod_stdmsgs`
  ADD CONSTRAINT `mod_stdmsgs_ibfk_1` FOREIGN KEY (`configid`) REFERENCES `mod_configs` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `newsfeed`
--
ALTER TABLE `newsfeed`
  ADD CONSTRAINT `newsfeed_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_ibfk_2` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_ibfk_3` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_ibfk_4` FOREIGN KEY (`eventid`) REFERENCES `communityevents` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_ibfk_5` FOREIGN KEY (`volunteeringid`) REFERENCES `volunteering` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_ibfk_6` FOREIGN KEY (`publicityid`) REFERENCES `groups_facebook_toshare` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_ibfk_7` FOREIGN KEY (`storyid`) REFERENCES `users_stories` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `newsfeed_likes`
--
ALTER TABLE `newsfeed_likes`
  ADD CONSTRAINT `newsfeed_likes_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_likes_ibfk_3` FOREIGN KEY (`newsfeedid`) REFERENCES `newsfeed` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `newsfeed_reports`
--
ALTER TABLE `newsfeed_reports`
  ADD CONSTRAINT `newsfeed_reports_ibfk_1` FOREIGN KEY (`newsfeedid`) REFERENCES `newsfeed` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_reports_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `newsfeed_unfollow`
--
ALTER TABLE `newsfeed_unfollow`
  ADD CONSTRAINT `newsfeed_unfollow_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsfeed_unfollow_ibfk_2` FOREIGN KEY (`newsfeedid`) REFERENCES `newsfeed` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `newsfeed_users`
--
ALTER TABLE `newsfeed_users`
  ADD CONSTRAINT `newsfeed_users_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `newsletters`
--
ALTER TABLE `newsletters`
  ADD CONSTRAINT `newsletters_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `newsletters_articles`
--
ALTER TABLE `newsletters_articles`
  ADD CONSTRAINT `newsletters_articles_ibfk_1` FOREIGN KEY (`newsletterid`) REFERENCES `newsletters` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `newsletters_articles_ibfk_2` FOREIGN KEY (`photoid`) REFERENCES `newsletters_images` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `newsletters_images`
--
ALTER TABLE `newsletters_images`
  ADD CONSTRAINT `newsletters_images_ibfk_1` FOREIGN KEY (`articleid`) REFERENCES `newsletters_articles` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `paf_addresses`
--
ALTER TABLE `paf_addresses`
  ADD CONSTRAINT `paf_addresses_ibfk_11` FOREIGN KEY (`postcodeid`) REFERENCES `locations` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `plugin`
--
ALTER TABLE `plugin`
  ADD CONSTRAINT `plugin_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `polls`
--
ALTER TABLE `polls`
  ADD CONSTRAINT `polls_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `polls_users`
--
ALTER TABLE `polls_users`
  ADD CONSTRAINT `polls_users_ibfk_1` FOREIGN KEY (`pollid`) REFERENCES `polls` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `polls_users_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `schedules_users`
--
ALTER TABLE `schedules_users`
  ADD CONSTRAINT `schedules_users_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `schedules_users_ibfk_2` FOREIGN KEY (`scheduleid`) REFERENCES `schedules` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `sessions`
--
ALTER TABLE `sessions`
  ADD CONSTRAINT `sessions_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `shortlinks`
--
ALTER TABLE `shortlinks`
  ADD CONSTRAINT `shortlinks_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `spam_users`
--
ALTER TABLE `spam_users`
  ADD CONSTRAINT `spam_users_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `spam_users_ibfk_2` FOREIGN KEY (`byuserid`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `spam_whitelist_links`
--
ALTER TABLE `spam_whitelist_links`
  ADD CONSTRAINT `spam_whitelist_links_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `stats`
--
ALTER TABLE `stats`
  ADD CONSTRAINT `_stats_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `users_ibfk_1` FOREIGN KEY (`lastlocation`) REFERENCES `locations` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `users_addresses`
--
ALTER TABLE `users_addresses`
  ADD CONSTRAINT `users_addresses_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_addresses_ibfk_3` FOREIGN KEY (`pafid`) REFERENCES `paf_addresses` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_banned`
--
ALTER TABLE `users_banned`
  ADD CONSTRAINT `users_banned_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_banned_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_banned_ibfk_3` FOREIGN KEY (`byuser`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `users_comments`
--
ALTER TABLE `users_comments`
  ADD CONSTRAINT `users_comments_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_comments_ibfk_2` FOREIGN KEY (`byuserid`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `users_comments_ibfk_3` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_donations`
--
ALTER TABLE `users_donations`
  ADD CONSTRAINT `users_donations_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `users_donations_asks`
--
ALTER TABLE `users_donations_asks`
  ADD CONSTRAINT `users_donations_asks_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_emails`
--
ALTER TABLE `users_emails`
  ADD CONSTRAINT `users_emails_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_images`
--
ALTER TABLE `users_images`
  ADD CONSTRAINT `users_images_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_invitations`
--
ALTER TABLE `users_invitations`
  ADD CONSTRAINT `users_invitations_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_logins`
--
ALTER TABLE `users_logins`
  ADD CONSTRAINT `users_logins_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_nearby`
--
ALTER TABLE `users_nearby`
  ADD CONSTRAINT `users_nearby_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_nearby_ibfk_2` FOREIGN KEY (`msgid`) REFERENCES `messages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_notifications`
--
ALTER TABLE `users_notifications`
  ADD CONSTRAINT `users_notifications_ibfk_1` FOREIGN KEY (`fromuser`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_notifications_ibfk_2` FOREIGN KEY (`newsfeedid`) REFERENCES `newsfeed` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_notifications_ibfk_3` FOREIGN KEY (`touser`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_nudges`
--
ALTER TABLE `users_nudges`
  ADD CONSTRAINT `users_nudges_ibfk_1` FOREIGN KEY (`fromuser`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_nudges_ibfk_2` FOREIGN KEY (`touser`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_phones`
--
ALTER TABLE `users_phones`
  ADD CONSTRAINT `users_phones_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_push_notifications`
--
ALTER TABLE `users_push_notifications`
  ADD CONSTRAINT `users_push_notifications_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_requests`
--
ALTER TABLE `users_requests`
  ADD CONSTRAINT `users_requests_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_requests_ibfk_2` FOREIGN KEY (`addressid`) REFERENCES `users_addresses` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_requests_ibfk_3` FOREIGN KEY (`completedby`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `users_stories`
--
ALTER TABLE `users_stories`
  ADD CONSTRAINT `users_stories_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `users_stories_likes`
--
ALTER TABLE `users_stories_likes`
  ADD CONSTRAINT `users_stories_likes_ibfk_1` FOREIGN KEY (`storyid`) REFERENCES `users_stories` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `users_stories_likes_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_stories_requested`
--
ALTER TABLE `users_stories_requested`
  ADD CONSTRAINT `users_stories_requested_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `users_thanks`
--
ALTER TABLE `users_thanks`
  ADD CONSTRAINT `users_thanks_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `volunteering_dates`
--
ALTER TABLE `volunteering_dates`
  ADD CONSTRAINT `volunteering_dates_ibfk_1` FOREIGN KEY (`volunteeringid`) REFERENCES `volunteering` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `volunteering_groups`
--
ALTER TABLE `volunteering_groups`
  ADD CONSTRAINT `volunteering_groups_ibfk_1` FOREIGN KEY (`volunteeringid`) REFERENCES `volunteering` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `volunteering_groups_ibfk_2` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `vouchers`
--
ALTER TABLE `vouchers`
  ADD CONSTRAINT `vouchers_ibfk_1` FOREIGN KEY (`groupid`) REFERENCES `groups` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `vouchers_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE SET NULL;

DELIMITER $$
--
-- Events
--
CREATE DEFINER=`root`@`localhost` EVENT `Delete Stranded Messages` ON SCHEDULE EVERY 1 DAY STARTS '2015-12-23 04:30:00' ON COMPLETION PRESERVE DISABLE ON SLAVE DO DELETE FROM messages WHERE id NOT IN (SELECT DISTINCT msgid FROM messages_groups)$$

CREATE DEFINER=`root`@`localhost` EVENT `Delete Non-Freegle Old Messages` ON SCHEDULE EVERY 1 DAY STARTS '2016-01-02 04:00:00' ON COMPLETION PRESERVE DISABLE ON SLAVE COMMENT 'Non-Freegle groups don''t have old messages preserved.' DO SELECT * FROM messages INNER JOIN messages_groups ON messages.id = messages_groups.msgid INNER JOIN groups ON messages_groups.groupid = groups.id WHERE  DATEDIFF(NOW(), `date`) > 31 AND groups.type != 'Freegle'$$

CREATE DEFINER=`root`@`localhost` EVENT `Delete Old Sessions` ON SCHEDULE EVERY 1 DAY STARTS '2016-01-29 04:00:00' ON COMPLETION PRESERVE DISABLE ON SLAVE DO DELETE FROM sessions WHERE DATEDIFF(NOW(), `date`) > 31$$

CREATE DEFINER=`root`@`localhost` EVENT `Delete Old API logs` ON SCHEDULE EVERY 1 DAY STARTS '2016-02-06 04:00:00' ON COMPLETION PRESERVE DISABLE ON SLAVE COMMENT 'Causes cluster hang - will replace with cron' DO DELETE FROM logs_api WHERE DATEDIFF(NOW(), `date`) > 2$$

CREATE DEFINER=`root`@`localhost` EVENT `Delete Old SQL Logs` ON SCHEDULE EVERY 1 DAY STARTS '2016-02-06 04:30:00' ON COMPLETION PRESERVE DISABLE ON SLAVE COMMENT 'Causes cluster hang - will replace with cron' DO DELETE FROM logs_sql WHERE DATEDIFF(NOW(), `date`) > 2$$

CREATE DEFINER=`root`@`localhost` EVENT `Update Member Counts` ON SCHEDULE EVERY 1 HOUR STARTS '2016-03-02 20:17:39' ON COMPLETION PRESERVE DISABLE ON SLAVE DO update groups set membercount = (select count(*) from memberships where groupid = groups.id)$$

CREATE DEFINER=`root`@`localhost` EVENT `Fix FBUser names` ON SCHEDULE EVERY 1 HOUR STARTS '2016-04-03 08:02:30' ON COMPLETION PRESERVE DISABLE ON SLAVE DO UPDATE users SET fullname = yahooid WHERE yahooid IS NOT NULL AND fullname LIKE  'fbuser%'$$

CREATE DEFINER=`root`@`localhost` EVENT `Delete Unlicensed Groups` ON SCHEDULE EVERY 1 DAY STARTS '2015-12-23 04:00:00' ON COMPLETION PRESERVE DISABLE ON SLAVE DO UPDATE groups SET publish = 0 WHERE licenserequired = 1 AND (licenseduntil IS NULL OR licenseduntil < NOW()) AND (trial IS NULL OR DATEDIFF(NOW(), trial) > 30)$$

DELIMITER ;
