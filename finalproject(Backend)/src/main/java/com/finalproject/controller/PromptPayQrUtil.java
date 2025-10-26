package com.finalproject.controller;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.common.BitMatrix;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
public class PromptPayQrUtil {


    public static String toQrBase64(String payload, int size) throws Exception {
        com.google.zxing.qrcode.QRCodeWriter writer = new com.google.zxing.qrcode.QRCodeWriter();
        com.google.zxing.common.BitMatrix matrix;
        try {
            matrix = writer.encode(payload, com.google.zxing.BarcodeFormat.QR_CODE, size, size);
        } catch (com.google.zxing.WriterException e) {
            throw new Exception("สร้าง QR ไม่สำเร็จ: " + e.getMessage(), e);
        }
        java.awt.image.BufferedImage image = com.google.zxing.client.j2se.MatrixToImageWriter.toBufferedImage(matrix);
        java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(image, "png", baos);
        return java.util.Base64.getEncoder().encodeToString(baos.toByteArray());
    }
}
