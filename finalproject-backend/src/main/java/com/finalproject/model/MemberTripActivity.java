package com.finalproject.model;

import com.fasterxml.jackson.annotation.JsonBackReference;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "membertripactivity")
@IdClass(MemberTripActivityId.class)
@AllArgsConstructor
@NoArgsConstructor
@Data
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class MemberTripActivity {

    @Id
    @ManyToOne
    @JoinColumn(name = "memberTripId", nullable = false)
    private MemberTrip memberTrip;

    @Id
    @JsonBackReference
    @ManyToOne
    @JoinColumn(name = "activityId", nullable = false)
    private Activity activity;

    @Column(name = "pricePerPerson", nullable = false)
    private Double pricePerPerson;
}
