CREATE DATABASE  IF NOT EXISTS `finalproject` /*!40100 DEFAULT CHARACTER SET utf8 */;
USE `finalproject`;
-- MySQL dump 10.13  Distrib 5.7.9, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: finalproject
-- ------------------------------------------------------
-- Server version	5.7.10-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `activity`
--

DROP TABLE IF EXISTS `activity`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `activity` (
  `activityId` int(11) NOT NULL AUTO_INCREMENT,
  `activityPrice` double NOT NULL,
  `tripId` int(11) NOT NULL,
  `activityDateTime` datetime(6) NOT NULL,
  `activityDetail` text NOT NULL,
  `activityName` varchar(255) NOT NULL,
  `imagePaymentaActivity` varchar(255) NOT NULL,
  PRIMARY KEY (`activityId`),
  KEY `FK1oshncgiyx9l9es5mrvvx12hc` (`tripId`),
  CONSTRAINT `FK1oshncgiyx9l9es5mrvvx12hc` FOREIGN KEY (`tripId`) REFERENCES `trip` (`tripId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `activity`
--

LOCK TABLES `activity` WRITE;
/*!40000 ALTER TABLE `activity` DISABLE KEYS */;
/*!40000 ALTER TABLE `activity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `members`
--

DROP TABLE IF EXISTS `members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `members` (
  `email` varchar(255) NOT NULL,
  `firstName` varchar(255) NOT NULL,
  `lastName` varchar(255) NOT NULL,
  `member_image` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `promtpayNumber` varchar(255) NOT NULL,
  `tel` varchar(255) NOT NULL,
  `username` varchar(255) NOT NULL,
  PRIMARY KEY (`email`),
  UNIQUE KEY `UKlj4daw762ura5d2y6iu7g5n1i` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `members`
--

LOCK TABLES `members` WRITE;
/*!40000 ALTER TABLE `members` DISABLE KEYS */;
INSERT INTO `members` VALUES ('jeng@gmail.com','aaaaaaaaaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaa','member_jeng_1761288143652.jpg','pbkdf2$120000$po89iBBCpJb+O+gsGCC6Yw==$HXJKgNuTrepON1Czzp0ofGo5pnKuJ5aAkgWmR/dVkSo=','0932560700','0932560700','jeng'),('kapom@gmail.com','aaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaa','member_kapom_1761288088128.jpg','pbkdf2$120000$XIOLX4fFhVXd5LM40gKgug==$DjziE3MXdRh79vnHkkp36u+Nga4c57gPiOWNRPX2vIY=','0932560700','0932560700','kapom');
/*!40000 ALTER TABLE `members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `membertripactivity`
--

DROP TABLE IF EXISTS `membertripactivity`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `membertripactivity` (
  `activityId` int(11) NOT NULL,
  `memberTripId` int(11) NOT NULL,
  `pricePerPerson` double NOT NULL,
  PRIMARY KEY (`activityId`,`memberTripId`),
  KEY `FKgve5s3dyj4by6vik2v1uihrg0` (`memberTripId`),
  CONSTRAINT `FKf8mscclics49f1vru8d4nn3no` FOREIGN KEY (`activityId`) REFERENCES `activity` (`activityId`),
  CONSTRAINT `FKgve5s3dyj4by6vik2v1uihrg0` FOREIGN KEY (`memberTripId`) REFERENCES `membertrips` (`memberTripId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `membertripactivity`
--

LOCK TABLES `membertripactivity` WRITE;
/*!40000 ALTER TABLE `membertripactivity` DISABLE KEYS */;
/*!40000 ALTER TABLE `membertripactivity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `membertrips`
--

DROP TABLE IF EXISTS `membertrips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `membertrips` (
  `memberTripId` int(11) NOT NULL AUTO_INCREMENT,
  `tripId` int(11) NOT NULL,
  `dateJoin` datetime(6) NOT NULL,
  `email` varchar(255) NOT NULL,
  `memberTripStatus` varchar(255) NOT NULL,
  PRIMARY KEY (`memberTripId`),
  KEY `FK4ryx7u1uabw1ot0mpad0nark4` (`email`),
  KEY `FK22swqxo2mpmrxq2217pw41mgk` (`tripId`),
  CONSTRAINT `FK22swqxo2mpmrxq2217pw41mgk` FOREIGN KEY (`tripId`) REFERENCES `trip` (`tripId`),
  CONSTRAINT `FK4ryx7u1uabw1ot0mpad0nark4` FOREIGN KEY (`email`) REFERENCES `members` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `membertrips`
--

LOCK TABLES `membertrips` WRITE;
/*!40000 ALTER TABLE `membertrips` DISABLE KEYS */;
INSERT INTO `membertrips` VALUES (1,1,'2025-10-24 06:43:11.148000','jeng@gmail.com','owner'),(2,1,'2025-10-24 06:43:23.774000','kapom@gmail.com','participant');
/*!40000 ALTER TABLE `membertrips` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `payment`
--

DROP TABLE IF EXISTS `payment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `payment` (
  `memberTripId` int(11) NOT NULL,
  `paymentId` int(11) NOT NULL AUTO_INCREMENT,
  `price` double NOT NULL,
  `datetimePayment` datetime(6) DEFAULT NULL,
  `paymentDetail` varchar(255) NOT NULL,
  `paymentSlip` varchar(255) DEFAULT NULL,
  `paymentStatus` varchar(255) NOT NULL,
  PRIMARY KEY (`paymentId`),
  KEY `FKcob4yqxp58twt74q6q9dp3f4i` (`memberTripId`),
  CONSTRAINT `FKcob4yqxp58twt74q6q9dp3f4i` FOREIGN KEY (`memberTripId`) REFERENCES `membertrips` (`memberTripId`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payment`
--

LOCK TABLES `payment` WRITE;
/*!40000 ALTER TABLE `payment` DISABLE KEYS */;
INSERT INTO `payment` VALUES (1,1,0,'2025-10-24 06:43:11.148000','ค่าเข้าร่วม',NULL,'Correct');
/*!40000 ALTER TABLE `payment` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `trip`
--

DROP TABLE IF EXISTS `trip`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `trip` (
  `budget` double NOT NULL,
  `tripId` int(11) NOT NULL AUTO_INCREMENT,
  `dueDate` datetime(6) NOT NULL,
  `startDate` datetime(6) NOT NULL,
  `image` varchar(255) NOT NULL,
  `location` varchar(255) NOT NULL,
  `tripDetail` varchar(255) NOT NULL,
  `tripName` varchar(255) NOT NULL,
  `tripStatus` varchar(255) NOT NULL,
  PRIMARY KEY (`tripId`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `trip`
--

LOCK TABLES `trip` WRITE;
/*!40000 ALTER TABLE `trip` DISABLE KEYS */;
INSERT INTO `trip` VALUES (0,1,'2025-10-25 05:00:00.000000','2025-10-24 05:00:00.000000','trip_1761288191138.jpg','{\"id\":\"A10453564\",\"name\":\"แม่โจ้\",\"address\":\"ลาดพร้าววังหิน 6 แขวงลาดพร้าว เขตลาดพร้าว กรุงเทพมหานคร 10230\",\"lat\":13.803905,\"lon\":100.594146}','ฟฟฟฟฟฟฟฟฟ','sssssssssssssssssssss','เปิดเข้าร่วม');
/*!40000 ALTER TABLE `trip` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-10-26 23:01:32
