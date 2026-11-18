// Fechas en horario local (Argentina): `toISOString()` usa UTC, así que
// después de las 21:00 devuelve el día siguiente. Todas las fechas que se
// guardan en la base (columnas `date`) deben generarse con estas funciones.

export function isoLocal(fecha = new Date()) {
  const anio = fecha.getFullYear()
  const mes = String(fecha.getMonth() + 1).padStart(2, '0')
  const dia = String(fecha.getDate()).padStart(2, '0')
  return `${anio}-${mes}-${dia}`
}

export function sumarDias(iso, dias) {
  const [anio, mes, dia] = iso.split('-').map(Number)
  const fecha = new Date(anio, mes - 1, dia)
  fecha.setDate(fecha.getDate() + dias)
  return isoLocal(fecha)
}

export function primerDiaDelMes(fecha = new Date()) {
  return isoLocal(new Date(fecha.getFullYear(), fecha.getMonth(), 1))
}
