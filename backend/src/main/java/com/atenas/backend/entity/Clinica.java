package com.atenas.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "clinica")
@Getter
@Setter
@NoArgsConstructor
public class Clinica {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @Column(name = "nombre", nullable = false, length = 150)
    private String nombre;

    @Column(name = "tipo", length = 100)
    private String tipo;

    // ciudad_id es nullable: permite registrar clínicas sin ciudad asignada aún
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ciudad_id")
    private Ciudad ciudad;

    @Column(name = "contacto_nombre", length = 150)
    private String contactoNombre;

    @Column(name = "contacto_email", length = 150)
    private String contactoEmail;

    @Column(name = "contacto_telefono", length = 30)
    private String contactoTelefono;

    @Column(name = "fecha_baja")
    private OffsetDateTime fechaBaja;
}