package com.finalproject.model;

import com.fasterxml.jackson.annotation.JsonBackReference;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonManagedReference;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

@Entity
@Table(name = "membertrips")
@AllArgsConstructor
@NoArgsConstructor
@Data
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class MemberTrip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "memberTripId")
    private Integer memberTripId;

    @Column(name = "dateJoin", nullable = false)
    private Date dateJoin;

    @Column(name = "memberTripStatus", nullable = false)
    private String memberTripStatus;

    @ManyToOne
    @JoinColumn(name = "email", nullable = false)
    @JsonManagedReference
    private Member participant;



    @ManyToOne
    @JsonBackReference
    @JoinColumn(name = "tripId", nullable = false)
    private Trip trip;

    // ใน MemberTrip.java
    @OneToMany(mappedBy = "membertrip", cascade = CascadeType.ALL, orphanRemoval = true)
    @JsonManagedReference
    private List<Payment> payments = new ArrayList<>();



}
