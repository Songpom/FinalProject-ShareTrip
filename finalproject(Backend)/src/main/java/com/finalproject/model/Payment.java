package com.finalproject.model;

import com.fasterxml.jackson.annotation.JsonBackReference;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Date;

@Entity
@Table(name = "payment")
@AllArgsConstructor
@NoArgsConstructor
@Data
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "paymentId")
    private Integer paymentId;

    @Column(name = "paymentStatus", nullable = false)
    private String paymentStatus;

    @Column(name = "price", nullable = false)
    private Double price;

    @Column(name = "paymentDetail", nullable = false)
    private String paymentDetail;

    @Column(name = "paymentSlip")
    private String paymentSlip;

    @Column(name = "datetimePayment")
    private Date datetimePayment;

    // ใน Payment.java
    @ManyToOne
    @JoinColumn(name = "memberTripId", nullable = false)
    @JsonBackReference
    private MemberTrip membertrip;

}
