package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.SemanaEstado;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "semana_laboral")
@Getter
@Setter
@NoArgsConstructor
public class SemanaLaboral {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @Column(name = "fecha_inicio", nullable = false, unique = true)
    private LocalDate fechaInicio;

    @Column(name = "fecha_fin", nullable = false)
    private LocalDate fechaFin;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false)
    private SemanaEstado estado;
}