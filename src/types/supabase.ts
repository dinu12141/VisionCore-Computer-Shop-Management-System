export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export interface Database {
  public: {
    Tables: {
      // Add your tables here if they are generated
      [key: string]: any
    }
    Views: {
      [key: string]: any
    }
    Functions: {
      [key: string]: any
    }
    Enums: {
      [key: string]: any
    }
  }
}
