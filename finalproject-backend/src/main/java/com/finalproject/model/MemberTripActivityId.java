package com.finalproject.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.Objects;

@AllArgsConstructor
@NoArgsConstructor
@Data
public class MemberTripActivityId implements Serializable {
    private Integer memberTrip;
    private Integer activity;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof MemberTripActivityId)) return false;
        MemberTripActivityId that = (MemberTripActivityId) o;
        return Objects.equals(memberTrip, that.memberTrip) &&
                Objects.equals(activity, that.activity);
    }

    @Override
    public int hashCode() {
        return Objects.hash(memberTrip, activity);
    }
}
