import { type_agency } from "@/app/protected/agency/data-types";
import { type_application } from "@/app/protected/data-types";


export const sampleAgencyData: type_agency[] = [
    {
      "partId": 0,
      "agencyAssignment": {
        "agencyId": 0,
        "identifierCode": "a1",
        "agencyName": "agency 1"
      },
      "paasSequence": 0,
      "paasAdministratorYN": true,
      "roles": [
        "string"
      ]
    },
    {
      "partId": 1,
      "agencyAssignment": {
        "agencyId": 1,
        "identifierCode": "a2",
        "agencyName": "agency 2"
      },
      "paasSequence": 1,
      "paasAdministratorYN": true,
      "roles": [
        "string"
      ]
    }
  ];


  export const sampleAppData: type_application[] = [
    {
      code: "001",
      description: "Sample description 1",
      name: "Sample Name 1",
      birthDate: new Date("1990-01-01"),
      email: "sample1@example.com"
  },
  {
      code: "002",
      description: "Sample description 2",
      name: "Sample Name 2",
      birthDate: new Date("1995-05-15"),
      email: "sample2@example.com"
  },
  {
      code: "003",
      description: "Sample description 3",
      name: "Sample Name 3",
      birthDate: new Date("1988-10-30"),
      email: "sample3@example.com"
  }
  ];