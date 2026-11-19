export function traducirError(mensajeOriginal = "") {
  const m = String(mensajeOriginal || "");

  if (m.includes("row-level security")) {
    return "No tenés permiso para hacer esta acción.";
  }
  if (m.includes("duplicate key") || m.includes("unique constraint")) {
    return "Ya existe un registro con esos datos.";
  }
  if (
    m.includes("violates foreign key") ||
    m.includes("foreign key constraint")
  ) {
    return "No se puede eliminar: hay otros registros asociados.";
  }
  if (m.includes("Ese horario ya está ocupado")) {
    return "Ese horario ya está ocupado por otro turno. Elegí otro.";
  }
  if (
    m.includes("check constraint") ||
    m.includes("violates check constraint")
  ) {
    return "Algunos datos no son válidos. Revisá el formulario.";
  }
  if (m.includes("schema cache") || m.includes("Could not find the table")) {
    return "Esta función todavía no está disponible en la base. Aplicá el archivo database.sql en Supabase.";
  }
  if (m.includes("Could not find the function")) {
    return "Esta función todavía no está disponible en la base. Aplicá el archivo database.sql en Supabase.";
  }
  return m || "Ocurrió un error inesperado. Intentá nuevamente.";
}
